/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

const vscode = require("vscode");

const LM_VENDOR = "claw.demo";
const STUB_MODEL = {
	id: "demo-stub",
	name: "Demo Stub",
	family: "demo",
	version: "1.0.0",
	maxInputTokens: 8192,
	maxOutputTokens: 8192,
	capabilities: {},
	isDefault: true,
};

/** @param {import("vscode").ExtensionContext} context */
function activate(context) {
	const log = vscode.window.createOutputChannel("OVS Chat Demo");
	log.appendLine("activate()");

	const lmProvider = vscode.lm.registerLanguageModelChatProvider(LM_VENDOR, {
		provideLanguageModelChatInformation(_options, _token) {
			log.appendLine("provideLanguageModelChatInformation");
			return [STUB_MODEL];
		},
		provideLanguageModelChatResponse(_model, _messages, _options, _progress, _token) {
			return Promise.resolve();
		},
		provideTokenCount(_model, _text, _token) {
			return Promise.resolve(1);
		},
	});
	log.appendLine("registerLanguageModelChatProvider ok");

	const participant = vscode.chat.createChatParticipant(
		"demo.chat",
		(request, _context, stream, _token) => {
			const text = (request.prompt || "").trim() || "(empty)";
			log.appendLine(`handler prompt=${JSON.stringify(text)}`);
			stream.progress("demo ok");
			stream.markdown(`**demo ok**\n\nYou said: \`${text}\`\n`);
			return { metadata: { command: "" } };
		}
	);
	log.appendLine("createChatParticipant ok");

	context.subscriptions.push(lmProvider, participant, log);
}

function deactivate() {}

module.exports = { activate, deactivate };
