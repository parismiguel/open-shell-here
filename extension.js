'use strict';

const vscode = require('vscode');
const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

/** Output channel for diagnostics, since the integrated terminal is often the thing that is broken. */
const channel = vscode.window.createOutputChannel('Open Shell Here');

function log(message) {
	channel.appendLine(`[${new Date().toISOString()}] ${message}`);
	channel.show(true);
}

function systemRoot() {
	return process.env.SystemRoot || process.env.windir || 'C:\\Windows';
}

/**
 * Built-in shells, probed in order. The first path that exists wins.
 *
 * `powershell` lists pwsh.exe (PowerShell 7) before powershell.exe
 * (Windows PowerShell 5.1) because most modern machines have both.
 */
const SHELLS = {
	powershell: {
		label: 'PowerShell',
		candidates: () => [
			'C:\\Program Files\\PowerShell\\7\\pwsh.exe',
			'C:\\Program Files\\PowerShell\\7-preview\\pwsh.exe',
			path.join(systemRoot(), 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
			path.join(systemRoot(), 'SysWOW64', 'WindowsPowerShell', 'v1.0', 'powershell.exe')
		],
		args: () => ['-NoLogo', '-NoExit']
	},
	cmd: {
		label: 'Command Prompt',
		candidates: () => [
			path.join(systemRoot(), 'System32', 'cmd.exe')
		],
		args: () => []
	},
	gitbash: {
		label: 'Git Bash',
		candidates: () => [
			'C:\\Program Files\\Git\\bin\\bash.exe',
			'C:\\Program Files\\Git\\git-bash.exe',
			'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
			'C:\\Program Files (x86)\\Git\\git-bash.exe'
		],
		args: () => ['-i']
	}
};

/**
 * Returns the shells to offer: the built-in defaults, or the user's own
 * profiles when `openShellHere.profiles` is configured and non-empty.
 *
 * @returns {Record<string, {label: string, candidates: () => string[], args: () => string[]}>}
 */
function getShells() {
	const configured = vscode.workspace.getConfiguration('openShellHere').get('profiles');

	if (!configured || typeof configured !== 'object' || Object.keys(configured).length === 0) {
		return SHELLS;
	}

	const custom = {};
	for (const [name, profile] of Object.entries(configured)) {
		if (!profile || typeof profile.path !== 'string' || profile.path.trim() === '') {
			log(`Skipping profile "${name}": no "path" property.`);
			continue;
		}

		custom[name] = {
			label: name,
			candidates: () => [profile.path.trim()],
			args: () => (Array.isArray(profile.args) ? profile.args.slice() : [])
		};
	}

	return Object.keys(custom).length > 0 ? custom : SHELLS;
}

/**
 * Returns the first existing executable for a shell id, or undefined.
 *
 * @param {string} id
 * @returns {string | undefined}
 */
function resolveExecutable(id) {
	const shell = getShells()[id];
	if (!shell) {
		return undefined;
	}

	for (const candidate of shell.candidates()) {
		try {
			if (fs.existsSync(candidate)) {
				return candidate;
			}
		} catch {
			// Unreadable candidate - fall through to the next one.
		}
	}
	return undefined;
}

/**
 * Determines the working directory: the right-clicked folder, or the parent
 * directory of a right-clicked file. Falls back to the first workspace folder.
 *
 * @param {import('vscode').Uri | undefined} resourceUri
 * @returns {string | undefined}
 */
function resolveCwd(resourceUri) {
	if (resourceUri && resourceUri.scheme === 'file') {
		const target = resourceUri.fsPath;
		try {
			if (fs.statSync(target).isDirectory()) {
				return target;
			}
			return path.dirname(target);
		} catch {
			// Fall through to the workspace folder below.
		}
	}

	const folders = vscode.workspace.workspaceFolders;
	if (folders && folders.length > 0) {
		return folders[0].uri.fsPath;
	}

	return undefined;
}

/**
 * Launches the shell in a new OS console window.
 *
 * This deliberately avoids node-pty: that library needs ConPTY, which is
 * unavailable on Windows versions before 1809 / Server 2019, and spawning the
 * executable directly works regardless of OS age.
 *
 * @param {string} id
 * @param {import('vscode').Uri | undefined} resourceUri
 * @returns {void}
 */
function launch(id, resourceUri) {
	const shell = getShells()[id];
	if (!shell) {
		log(`FAILED: unknown shell "${id}".`);
		vscode.window.showErrorMessage(`Open Shell Here: unknown shell "${id}".`);
		return;
	}

	const exe = resolveExecutable(id);
	if (!exe) {
		const tried = shell.candidates().join(', ');
		log(`FAILED: ${shell.label} not found. Checked: ${tried}`);
		vscode.window.showErrorMessage(`Open Shell Here: could not find ${shell.label}. Checked: ${tried}`);
		return;
	}

	const cwd = resolveCwd(resourceUri);
	if (!cwd) {
		log('FAILED: no folder selected and no workspace folder is open.');
		vscode.window.showErrorMessage('Open Shell Here: no folder selected and no workspace folder is open.');
		return;
	}

	// Launch through `cmd /c start`. The empty string is the window TITLE that
	// `start` expects as its first argument - without it, `start` treats the
	// executable path as the title and opens nothing.
	//
	// `detached: true` must NOT be used: on Windows it maps to DETACHED_PROCESS,
	// which gives the child no console at all, so the shell runs invisibly.
	const comspec = process.env.ComSpec || 'cmd.exe';
	const args = ['/c', 'start', '', exe, ...shell.args()];

	log(`Launching: ${shell.label}`);
	log(`  exe : ${exe}`);
	log(`  args: ${shell.args().join(' ')}`);
	log(`  cwd : ${cwd}`);

	let child;
	try {
		child = childProcess.spawn(comspec, args, {
			cwd: cwd,
			stdio: 'ignore',
			windowsHide: true,
			windowsVerbatimArguments: false
		});
	}
	catch (error) {
		log(`  THREW: ${error.message}`);
		vscode.window.showErrorMessage(`Open Shell Here: failed to launch ${shell.label} - ${error.message}`);
		return;
	}

	child.on('error', (error) => {
		log(`  ERROR EVENT: ${error.message}`);
		vscode.window.showErrorMessage(`Open Shell Here: failed to launch ${shell.label} - ${error.message}`);
	});

	child.on('exit', (code) => {
		log(`  launcher exited with code ${code}`);
		if (code !== 0) {
			vscode.window.showErrorMessage(`Open Shell Here: ${shell.label} launcher returned exit code ${code}. See the "Open Shell Here" output channel.`);
		}
	});

	child.unref();
	vscode.window.setStatusBarMessage(`Opening ${shell.label} at ${cwd}`, 4000);
}

/**
 * @param {import('vscode').ExtensionContext} context
 * @returns {void}
 */
function activate(context) {
	context.subscriptions.push(channel);

	// Keep the previous registrations so they can be disposed of when
	// openShellHere.profiles changes and the command set is rebuilt.
	let registrations = [];
	const registerCommands = () => {
		for (const disposable of registrations) {
			disposable.dispose();
		}
		registrations = [];

		for (const id of Object.keys(getShells())) {
			log(`Registered command: openShellHere.${id}`);
			registrations.push(
				vscode.commands.registerCommand(`openShellHere.${id}`, (resourceUri) => launch(id, resourceUri))
			);
		}
	};

	registerCommands();

	context.subscriptions.push(new vscode.Disposable(() => {
		for (const disposable of registrations) {
			disposable.dispose();
		}
	}));

	context.subscriptions.push(
		vscode.workspace.onDidChangeConfiguration((event) => {
			if (event.affectsConfiguration('openShellHere.profiles')) {
				log('openShellHere.profiles changed - re-registering commands.');
				registerCommands();
			}
		})
	);
}

/** @returns {void} */
function deactivate() {
	// Nothing to clean up: spawned shells are intentionally independent.
}

module.exports = { activate, deactivate };
		}
	}

	const folders = vscode.workspace.workspaceFolders;
	if (folders && folders.length > 0) {
		return folders[0].uri.fsPath;
	}

	return undefined;
}