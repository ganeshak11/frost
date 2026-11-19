#!/usr/bin/env python3
"""Build the "Frost Dark" colour theme for VS Code, Cursor and Antigravity
into extras/vscode/build/frost-theme.vsix (an ordinary VS Code extension).

Obsidian-glass greys, white text, Frost red (#F21D43) for focus, selection,
the active tab, badges and the status bar's accents. Syntax colours stay soft
so red keeps meaning "this is where you are".
"""
import json, zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "build"
VERSION = "1.0.0"

RED, RED2 = "#F21D43", "#FF4D6D"
BG, BG2, BG3, BG4 = "#0E0E12", "#121217", "#17171D", "#1E1F24"   # editor, panels, raised, hover
TEXT, MUTED, DIM = "#F2F2F5", "#9A9AA6", "#5E5E6E"
LINE = "#FFFFFF14"            # hairlines
SEL = RED + "38"              # selections: translucent red

colors = {
    "focusBorder": RED + "99", "foreground": TEXT, "descriptionForeground": MUTED, "errorForeground": "#FF5C5C",
    "widget.border": LINE, "widget.shadow": "#00000080", "selection.background": SEL,
    "icon.foreground": MUTED, "textLink.foreground": RED2, "textLink.activeForeground": RED,
    # window frame
    "titleBar.activeBackground": BG2, "titleBar.inactiveBackground": BG2, "titleBar.activeForeground": TEXT,
    "titleBar.inactiveForeground": MUTED, "titleBar.border": LINE,
    "menu.background": BG3, "menu.foreground": TEXT, "menu.selectionBackground": SEL, "menu.border": LINE,
    "menubar.selectionBackground": "#FFFFFF14",
    "commandCenter.background": "#FFFFFF0A", "commandCenter.border": LINE, "commandCenter.activeBorder": RED + "80",
    # activity bar and sidebar
    "activityBar.background": BG2, "activityBar.foreground": TEXT, "activityBar.inactiveForeground": DIM,
    "activityBar.activeBorder": RED, "activityBar.border": LINE,
    "activityBarBadge.background": RED, "activityBarBadge.foreground": "#FFFFFF",
    "sideBar.background": BG2, "sideBar.foreground": "#D8D8DE", "sideBar.border": LINE,
    "sideBarTitle.foreground": MUTED, "sideBarSectionHeader.background": BG2, "sideBarSectionHeader.border": LINE,
    "list.activeSelectionBackground": SEL, "list.activeSelectionForeground": TEXT,
    "list.inactiveSelectionBackground": "#FFFFFF10", "list.hoverBackground": "#FFFFFF0C",
    "list.focusOutline": RED + "80", "list.highlightForeground": RED2, "list.errorForeground": "#FF5C5C",
    "list.warningForeground": "#FFB02E", "tree.indentGuidesStroke": "#FFFFFF1F",
    # editor
    "editor.background": BG, "editor.foreground": TEXT, "editorLineNumber.foreground": "#4A4A56",
    "editorLineNumber.activeForeground": TEXT, "editorCursor.foreground": RED,
    "editor.selectionBackground": SEL, "editor.inactiveSelectionBackground": RED + "1C",
    "editor.selectionHighlightBackground": "#FFFFFF14", "editor.wordHighlightBackground": "#FFFFFF12",
    "editor.findMatchBackground": RED + "66", "editor.findMatchHighlightBackground": RED + "2E",
    "editor.lineHighlightBackground": "#FFFFFF07", "editor.lineHighlightBorder": "#00000000",
    "editorIndentGuide.background1": "#FFFFFF10", "editorIndentGuide.activeBackground1": "#FFFFFF33",
    "editorWhitespace.foreground": "#FFFFFF1A", "editorRuler.foreground": "#FFFFFF10",
    "editorBracketMatch.background": RED + "26", "editorBracketMatch.border": RED + "80",
    "editorGutter.addedBackground": "#34C759", "editorGutter.modifiedBackground": "#FFB02E", "editorGutter.deletedBackground": "#FF5C5C",
    "editorError.foreground": "#FF5C5C", "editorWarning.foreground": "#FFB02E", "editorInfo.foreground": "#9A9AA6",
    "editorWidget.background": BG3, "editorWidget.border": LINE, "editorSuggestWidget.background": BG3,
    "editorSuggestWidget.selectedBackground": SEL, "editorSuggestWidget.highlightForeground": RED2,
    "editorHoverWidget.background": BG3, "editorHoverWidget.border": LINE,
    "editorGroupHeader.tabsBackground": BG2, "editorGroupHeader.tabsBorder": LINE, "editorGroup.border": LINE,
    "breadcrumb.foreground": MUTED, "breadcrumb.focusForeground": TEXT, "breadcrumb.background": BG,
    "minimap.selectionHighlight": RED + "80", "minimapSlider.background": "#FFFFFF10",
    "scrollbarSlider.background": "#FFFFFF14", "scrollbarSlider.hoverBackground": "#FFFFFF24",
    "scrollbarSlider.activeBackground": RED + "80", "scrollbar.shadow": "#00000000",
    # tabs
    "tab.activeBackground": BG, "tab.activeForeground": TEXT, "tab.activeBorderTop": RED, "tab.activeBorder": BG,
    "tab.inactiveBackground": BG2, "tab.inactiveForeground": MUTED, "tab.border": LINE,
    "tab.hoverBackground": BG3, "tab.unfocusedActiveBorderTop": RED + "66",
    # panel, terminal, status bar
    "panel.background": BG2, "panel.border": LINE, "panelTitle.activeBorder": RED, "panelTitle.activeForeground": TEXT,
    "panelTitle.inactiveForeground": MUTED,
    "terminal.background": BG, "terminal.foreground": TEXT, "terminalCursor.foreground": RED,
    "terminal.selectionBackground": SEL,
    "terminal.ansiBlack": "#1E1F24", "terminal.ansiRed": "#F21D43", "terminal.ansiGreen": "#34C759",
    "terminal.ansiYellow": "#FFB02E", "terminal.ansiBlue": "#5AA0FF", "terminal.ansiMagenta": "#C9A7FF",
    "terminal.ansiCyan": "#7AD7E0", "terminal.ansiWhite": "#D8D8DE",
    "terminal.ansiBrightBlack": "#5E5E6E", "terminal.ansiBrightRed": "#FF4D6D", "terminal.ansiBrightGreen": "#5EE07F",
    "terminal.ansiBrightYellow": "#FFCB66", "terminal.ansiBrightBlue": "#8DBDFF", "terminal.ansiBrightMagenta": "#DCC6FF",
    "terminal.ansiBrightCyan": "#A6E8EE", "terminal.ansiBrightWhite": "#FFFFFF",
    "statusBar.background": BG2, "statusBar.foreground": MUTED, "statusBar.border": LINE,
    "statusBar.noFolderBackground": BG2, "statusBar.debuggingBackground": RED, "statusBar.debuggingForeground": "#FFFFFF",
    "statusBarItem.remoteBackground": RED, "statusBarItem.remoteForeground": "#FFFFFF",
    "statusBarItem.hoverBackground": "#FFFFFF14",
    # inputs and buttons
    "input.background": "#FFFFFF0A", "input.border": LINE, "input.foreground": TEXT, "input.placeholderForeground": DIM,
    "inputOption.activeBorder": RED, "inputOption.activeBackground": SEL,
    "dropdown.background": BG3, "dropdown.border": LINE,
    "button.background": RED, "button.foreground": "#FFFFFF", "button.hoverBackground": "#FF3358",
    "button.secondaryBackground": "#FFFFFF14", "button.secondaryForeground": TEXT,
    "badge.background": RED, "badge.foreground": "#FFFFFF", "progressBar.background": RED,
    "checkbox.background": "#FFFFFF0A", "checkbox.border": LINE,
    "notifications.background": BG3, "notifications.border": LINE, "notificationCenterHeader.background": BG3,
    "quickInput.background": BG3, "quickInputList.focusBackground": SEL, "pickerGroup.foreground": RED2,
    "peekView.border": RED + "80", "peekViewEditor.background": BG2, "peekViewResult.background": BG3,
    "peekViewTitle.background": BG3,
    "gitDecoration.modifiedResourceForeground": "#FFB02E", "gitDecoration.addedResourceForeground": "#34C759",
    "gitDecoration.untrackedResourceForeground": "#5EE07F", "gitDecoration.deletedResourceForeground": "#FF5C5C",
    "gitDecoration.ignoredResourceForeground": DIM, "gitDecoration.conflictingResourceForeground": RED2,
    "diffEditor.insertedTextBackground": "#34C75922", "diffEditor.removedTextBackground": "#FF5C5C22",
    "welcomePage.tileBackground": BG3, "walkThrough.embeddedEditorBackground": BG2,
}

KEY, FUNC, TYPE, STR, NUM, CONST, PROP, COMMENT = "#FF4D6D", "#FFB4C0", "#FFD27A", "#9EE6B4", "#C9A7FF", "#FF8FA3", "#B9C6FF", "#5E5E6E"
def rule(scope, fg, style=None):
    s = {"foreground": fg}
    if style: s["fontStyle"] = style
    return {"scope": scope, "settings": s}

tokens = [
    rule(["comment", "punctuation.definition.comment"], COMMENT, "italic"),
    rule(["keyword", "storage", "storage.type", "keyword.control", "keyword.operator.new", "keyword.operator.expression"], KEY),
    rule(["keyword.operator", "punctuation"], "#B0B0BA"),
    rule(["string", "string.template", "punctuation.definition.string"], STR),
    rule(["constant.character.escape", "string.regexp"], "#7AD7E0"),
    rule(["constant.numeric", "constant.language.boolean"], NUM),
    rule(["constant", "constant.language", "variable.other.constant", "support.constant"], CONST),
    rule(["entity.name.function", "support.function", "meta.function-call", "variable.function"], FUNC),
    rule(["entity.name.type", "entity.name.class", "support.type", "support.class", "entity.other.inherited-class",
          "storage.type.primitive", "entity.name.namespace"], TYPE),
    rule(["variable", "variable.other.readwrite", "meta.definition.variable"], TEXT),
    rule(["variable.parameter", "meta.parameters"], "#F5C7CF", "italic"),
    rule(["variable.other.property", "variable.other.object.property", "support.variable.property", "meta.object-literal.key",
          "entity.name.tag.yaml", "support.type.property-name"], PROP),
    rule(["variable.language.this", "variable.language.self", "variable.language.super"], KEY, "italic"),
    rule(["entity.name.tag", "meta.tag.sgml"], KEY),
    rule(["entity.other.attribute-name"], TYPE, "italic"),
    rule(["entity.name.decorator", "meta.decorator", "punctuation.decorator"], "#7AD7E0"),
    rule(["markup.heading", "entity.name.section"], RED2, "bold"),
    rule(["markup.bold"], TEXT, "bold"), rule(["markup.italic"], TEXT, "italic"),
    rule(["markup.inline.raw", "markup.fenced_code"], STR), rule(["markup.underline.link"], "#8DBDFF"),
    rule(["markup.inserted"], "#34C759"), rule(["markup.deleted"], "#FF5C5C"), rule(["markup.changed"], "#FFB02E"),
    rule(["invalid"], "#FF5C5C", "underline"),
]

theme = {"name": "Frost Dark", "type": "dark", "semanticHighlighting": True, "colors": colors, "tokenColors": tokens,
         "semanticTokenColors": {"parameter": "#F5C7CF", "property": PROP, "enumMember": CONST,
                                 "variable.readonly": CONST, "type": TYPE, "class": TYPE, "interface": TYPE,
                                 "function": FUNC, "method": FUNC, "namespace": TYPE}}

package = {
    "name": "frost-theme", "displayName": "Frost Dark", "description": "Frost: obsidian glass greys with a red accent",
    "publisher": "frost", "version": VERSION, "license": "MIT", "engines": {"vscode": "^1.70.0"},
    "categories": ["Themes"],
    "contributes": {"themes": [{"label": "Frost Dark", "uiTheme": "vs-dark", "path": "./themes/frost-dark.json"}]},
}

MANIFEST = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="frost-theme" Version="{VERSION}" Publisher="frost"/>
    <DisplayName>Frost Dark</DisplayName>
    <Description xml:space="preserve">Frost: obsidian glass greys with a red accent</Description>
    <Categories>Themes</Categories>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.70.0"/></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
"""
CONTENT_TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/><Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""

def main():
    OUT.mkdir(exist_ok=True)
    vsix = OUT / "frost-theme.vsix"
    with zipfile.ZipFile(vsix, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CONTENT_TYPES)
        z.writestr("extension.vsixmanifest", MANIFEST)
        z.writestr("extension/package.json", json.dumps(package, indent=2))
        z.writestr("extension/themes/frost-dark.json", json.dumps(theme, indent=2))
    print(f"built {vsix}")


if __name__ == "__main__":
    main()
