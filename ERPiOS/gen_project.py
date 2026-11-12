#!/usr/bin/env python3
# 重新生成 ERPiOS.xcodeproj（增删 Swift 文件后运行本脚本即可同步工程引用）
import os
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT / "ERPiOS"
PROJ = ROOT / "ERPiOS.xcodeproj"
TEAM = ""  # 填你自己的 Apple 开发者团队 ID（免费个人团队也可）
BUNDLE_ID = "com.workbuddy.erpdemo"

counter = [0]


def new_id():
    counter[0] += 1
    return "1A" + format(counter[0], "022X")


def q(s):
    s = str(s)
    if re.fullmatch(r"[A-Za-z0-9_./$-]+", s):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


SECTION_ORDER = [
    "PBXBuildFile", "PBXFileReference", "PBXFrameworksBuildPhase", "PBXGroup",
    "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase", "PBXSourcesBuildPhase",
    "XCBuildConfiguration", "XCConfigurationList",
]
sections = {k: [] for k in SECTION_ORDER}


def emit(section, oid, comment, body):
    sections[section].append("\t\t%s /* %s */ = {%s};\n" % (oid, comment, body))


build_file_ids = []
resource_file_ids = []


def scan(directory, group_name):
    """返回 (group_id, group_comment)"""
    children = []
    for entry in sorted(os.listdir(directory)):
        full = directory / entry
        if full.is_dir():
            gid, comment = scan(full, entry)
            children.append((gid, comment))
        elif entry.endswith(".plist"):
            # Info.plist 由 INFOPLIST_FILE 使用，不能再放进 Resources 阶段，
            # 否则会出现 "Multiple commands produce Info.plist"。
            fid = new_id()
            emit("PBXFileReference", fid, entry,
                 "isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
                 "path = %s; sourceTree = \"<group>\"; " % q(entry))
            children.append((fid, entry))
        elif entry.endswith(".html"):
            # 登录页地球背景（WKWebView 本地资源），需进入 Copy Bundle Resources
            fid = new_id()
            emit("PBXFileReference", fid, entry,
                 "isa = PBXFileReference; lastKnownFileType = text.html; "
                 "path = %s; sourceTree = \"<group>\"; " % q(entry))
            bid = new_id()
            emit("PBXBuildFile", bid, entry + " in Resources",
                 "isa = PBXBuildFile; fileRef = %s /* %s */; " % (fid, entry))
            resource_file_ids.append(bid)
            children.append((fid, entry))
        elif entry.endswith(".swift"):
            fid = new_id()
            emit("PBXFileReference", fid, entry,
                 "isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
                 "path = %s; sourceTree = \"<group>\"; " % q(entry))
            bid = new_id()
            emit("PBXBuildFile", bid, entry + " in Sources",
                 "isa = PBXBuildFile; fileRef = %s /* %s */; " % (fid, entry))
            build_file_ids.append(bid)
            children.append((fid, entry))
    gid = new_id()
    child_lines = "".join("\t\t\t\t%s /* %s */,\n" % (cid, c) for cid, c in children)
    body = ("isa = PBXGroup; children = (\n%s\t\t\t); path = %s; sourceTree = \"<group>\"; "
            % (child_lines, q(group_name)))
    emit("PBXGroup", gid, group_name, body)
    return gid, group_name


source_group_id, _ = scan(SRC, "ERPiOS")

product_ref = new_id()
emit("PBXFileReference", product_ref, "ERPiOS.app",
     "isa = PBXFileReference; explicitFileType = wrapper.application; "
     "includeInIndex = 0; path = ERPiOS.app; sourceTree = BUILT_PRODUCTS_DIR; ")

products_group = new_id()
emit("PBXGroup", products_group, "Products",
     "isa = PBXGroup; children = (\n\t\t\t\t%s /* ERPiOS.app */,\n\t\t\t); "
     "name = Products; sourceTree = \"<group>\"; " % product_ref)

main_group = new_id()
emit("PBXGroup", main_group, "Main Group",
     "isa = PBXGroup; children = (\n\t\t\t\t%s /* ERPiOS */,\n\t\t\t\t%s /* Products */,\n\t\t\t); "
     "sourceTree = \"<group>\"; " % (source_group_id, products_group))

sources_phase = new_id()
src_lines = "".join("\t\t\t\t%s,\n" % bid for bid in build_file_ids)
emit("PBXSourcesBuildPhase", sources_phase, "Sources",
     "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n%s\t\t\t); "
     "runOnlyForDeploymentPostprocessing = 0; " % src_lines)

frameworks_phase = new_id()
emit("PBXFrameworksBuildPhase", frameworks_phase, "Frameworks",
     "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (\n\t\t\t); "
     "runOnlyForDeploymentPostprocessing = 0; ")

resources_phase = new_id()
res_lines = "".join("\t\t\t\t%s,\n" % bid for bid in resource_file_ids)
emit("PBXResourcesBuildPhase", resources_phase, "Resources",
     "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (\n%s\t\t\t); "
     "runOnlyForDeploymentPostprocessing = 0; " % res_lines)

PROJECT_SETTINGS = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_STRICT_CONCURRENCY": "minimal",
    "SWIFT_VERSION": "5.0",
}

TARGET_SETTINGS = {
    "CODE_SIGN_IDENTITY": '"Apple Development"',
    '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"': '"Apple Development"',
    '"CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]"': "NO",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": '"$(SRCROOT)/ERPiOS/Resources/Info.plist"',
    "INFOPLIST_KEY_CFBundleDisplayName": '"云智 ERP"',
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':
        '"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown '
        'UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':
        '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft '
        'UIInterfaceOrientationLandscapeRight"',
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "MARKETING_VERSION": "0.1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_STRICT_CONCURRENCY": "minimal",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}


def settings_text(d, extra=None):
    lines = ["\t\t\t\t%s = %s;\n" % (k, v) for k, v in d.items()]
    if extra:
        for k, v in extra.items():
            lines.append("\t\t\t\t%s = %s;\n" % (k, v))
    return "isa = XCBuildConfiguration; buildSettings = {\n%s\t\t\t}; " % "".join(lines)


configs = {}
for name in ("Debug", "Release"):
    pid = new_id()
    emit("XCBuildConfiguration", pid, name,
         settings_text(PROJECT_SETTINGS,
                       {"DEBUG_INFORMATION_FORMAT": "dwarf",
                        "GCC_OPTIMIZATION_LEVEL": "0",
                        "GCC_PREPROCESSOR_DEFINITIONS": '"DEBUG=1 $(inherited)"',
                        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"'} if name == "Debug" else
                       {"DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
                        "SWIFT_COMPILATION_MODE": "wholemodule",
                        "SWIFT_OPTIMIZATION_LEVEL": '"-O"'}) +
         "name = %s; " % name)
    tid = new_id()
    emit("XCBuildConfiguration", tid, name,
         settings_text(TARGET_SETTINGS) + "name = %s; " % name)
    configs[name] = (pid, tid)

proj_config_list = new_id()
emit("XCConfigurationList", proj_config_list, "Build configuration list for PBXProject \"ERPiOS\"",
     "isa = XCConfigurationList; buildConfigurations = (\n\t\t\t\t%s /* Debug */,\n\t\t\t\t%s /* Release */,\n\t\t\t); "
     "defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; "
     % (configs["Debug"][0], configs["Release"][0]))

target_config_list = new_id()
emit("XCConfigurationList", target_config_list, "Build configuration list for PBXNativeTarget \"ERPiOS\"",
     "isa = XCConfigurationList; buildConfigurations = (\n\t\t\t\t%s /* Debug */,\n\t\t\t\t%s /* Release */,\n\t\t\t); "
     "defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; "
     % (configs["Debug"][1], configs["Release"][1]))

target_id = new_id()
emit("PBXNativeTarget", target_id, "ERPiOS",
     "isa = PBXNativeTarget; buildConfigurationList = %s; buildPhases = (\n"
     "\t\t\t\t%s /* Sources */,\n\t\t\t\t%s /* Frameworks */,\n\t\t\t\t%s /* Resources */,\n\t\t\t); "
     "buildRules = (\n\t\t\t); dependencies = (\n\t\t\t); name = ERPiOS; "
     "productName = ERPiOS; productReference = %s /* ERPiOS.app */; productType = \"com.apple.product-type.application\"; "
     % (target_config_list, sources_phase, frameworks_phase, resources_phase, product_ref))

project_id = new_id()
emit("PBXProject", project_id, "Project object",
     "isa = PBXProject; attributes = {\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
     "\t\t\t\tLastSwiftUpdateCheck = 2630;\n\t\t\t\tLastUpgradeCheck = 2630;\n"
     "\t\t\t\tTargetAttributes = {\n\t\t\t\t\t%s = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 26.3;\n\t\t\t\t\t};\n\t\t\t\t};\n\t\t\t}; "
     "buildConfigurationList = %s; compatibilityVersion = \"Xcode 14.0\"; "
     "developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t\t\"zh-Hans\",\n\t\t\t); "
     "mainGroup = %s; productRefGroup = %s /* Products */; projectDirPath = \"\"; "
     "projectRoot = \"\"; targets = (\n\t\t\t\t%s /* ERPiOS */,\n\t\t\t); "
     % (target_id, proj_config_list, main_group, products_group, target_id))

out = ["// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n"
       "\tobjectVersion = 56;\n\tobjects = {\n\n"]
for section in SECTION_ORDER:
    out.append("/* Begin %s section */\n" % section)
    out.extend(sections[section])
    out.append("/* End %s section */\n\n" % section)
out.append("\t};\n\trootObject = %s /* Project object */;\n}\n" % project_id)

(PROJ / "project.pbxproj").write_text("".join(out))

# 共享 scheme，保证 xcodebuild -scheme 可用
scheme_dir = PROJ / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
ref = ('<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="%s" '
       'BuildableName="ERPiOS.app" BlueprintName="ERPiOS" '
       'ReferencedContainer="container:ERPiOS.xcodeproj"></BuildableReference>' % target_id)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            {ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables></Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         {ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         {ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"></ArchiveAction>
</Scheme>
'''
(scheme_dir / "ERPiOS.xcscheme").write_text(scheme)

ws = PROJ / "project.xcworkspace"
if not ws.exists():
    ws.mkdir(parents=True, exist_ok=True)
(ws / "contents.xcworkspacedata").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<Workspace version = "1.0">\n   <FileRef location = "self:">\n   </FileRef>\n</Workspace>\n')

print("Swift files:", len(build_file_ids))
print("pbxproj bytes:", (PROJ / "project.pbxproj").stat().st_size)
print("target id:", target_id)
