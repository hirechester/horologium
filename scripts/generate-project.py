#!/usr/bin/env python3
"""Generate the dependency-free Xcode project. Run after adding Swift/resource files."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
objects = {}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, value):
    objects[ident(key)] = value
    return ident(key)
def quote(s): return json.dumps(str(s))
def obj(isa, **fields): return dict(isa=isa, **fields)
app_files = sorted((root / 'Horologium').rglob('*.swift'))
test_files = sorted((root / 'HorologiumTests').glob('*.swift'))
resource_files = sorted((root / 'Horologium/Resources').glob('*'))
refs = []
def files(paths, kind):
    builds = []
    for p in paths:
        path = str(p.relative_to(root))
        ref = add(path, obj('PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>'))
        refs.append(ref)
        builds.append(add('build:'+path, obj('PBXBuildFile', fileRef=ref)))
    return builds
app_sources = files(app_files, 'sourcecode.swift')
test_sources = files(test_files, 'sourcecode.swift')
resources = files(resource_files, 'file')
app_product = add('app-product', obj('PBXFileReference', explicitFileType='wrapper.application', path='Horologium.app', sourceTree='BUILT_PRODUCTS_DIR'))
test_product = add('test-product', obj('PBXFileReference', explicitFileType='wrapper.cfbundle', path='HorologiumTests.xctest', sourceTree='BUILT_PRODUCTS_DIR'))
products = add('products', obj('PBXGroup', children=[app_product, test_product], name='Products', sourceTree='<group>'))
main_group = add('main-group', obj('PBXGroup', children=refs+[products], sourceTree='<group>'))
def phase(key, isa, builds): return add(key, obj(isa, buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0))
app_phases = [phase('app-sources','PBXSourcesBuildPhase',app_sources), phase('app-frameworks','PBXFrameworksBuildPhase',[]), phase('app-resources','PBXResourcesBuildPhase',resources)]
test_phases = [phase('test-sources','PBXSourcesBuildPhase',test_sources), phase('test-frameworks','PBXFrameworksBuildPhase',[]), phase('test-resources','PBXResourcesBuildPhase',[])]
def configs(key, settings):
    cs = []
    for name in ['Debug','Release']:
        build = settings.copy()
        build.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O', 'DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym', 'ENABLE_TESTABILITY':'YES' if name=='Debug' else 'NO'})
        if name == 'Debug': build['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        cs.append(add(key+name, obj('XCBuildConfiguration', buildSettings=build, name=name)))
    return add(key+'configs', obj('XCConfigurationList', buildConfigurations=cs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release'))
project_config = configs('project', {'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'26.0','ARCHS':'arm64','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','ENABLE_TESTABILITY':'YES','CODE_SIGN_STYLE':'Automatic'})
app_config = configs('app', {'PRODUCT_NAME':'Horologium','PRODUCT_BUNDLE_IDENTIFIER':'app.ardens.horologium','INFOPLIST_FILE':'Horologium/Info.plist','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1','ENABLE_HARDENED_RUNTIME':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks'})
test_config = configs('test', {'PRODUCT_NAME':'HorologiumTests','PRODUCT_BUNDLE_IDENTIFIER':'app.ardens.horologium.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Horologium.app/Contents/MacOS/Horologium','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'})
app_target = add('app-target', obj('PBXNativeTarget', buildConfigurationList=app_config, buildPhases=app_phases, buildRules=[], dependencies=[], name='Horologium', productName='Horologium', productReference=app_product, productType='com.apple.product-type.application'))
proxy = add('proxy', obj('PBXContainerItemProxy', containerPortal=ident('project'), proxyType=1, remoteGlobalIDString=app_target, remoteInfo='Horologium'))
dependency = add('dependency', obj('PBXTargetDependency', target=app_target, targetProxy=proxy))
test_target = add('test-target', obj('PBXNativeTarget', buildConfigurationList=test_config, buildPhases=test_phases, buildRules=[], dependencies=[dependency], name='HorologiumTests', productName='HorologiumTests', productReference=test_product, productType='com.apple.product-type.bundle.unit-test'))
project = add('project', obj('PBXProject', attributes={'LastUpgradeCheck':'2700'}, buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0, knownRegions=['en','Base'], mainGroup=main_group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app_target,test_target]))
def serialize(value, level=0):
    pad = '\t' * level
    if isinstance(value, dict): return '{\n' + ''.join(pad+'\t'+quote(k)+' = '+serialize(v, level+1)+';\n' for k,v in value.items())+pad+'}'
    if isinstance(value, list): return '('+', '.join(serialize(x, level) for x in value)+')'
    if isinstance(value, int): return str(value)
    return quote(value)
output = '// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n'
(root/'Horologium.xcodeproj/project.pbxproj').write_text(output)
def reference(target, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Horologium.xcodeproj"/>'
app_ref = reference(app_target,'Horologium','Horologium.app')
test_ref = reference(test_target,'HorologiumTests','HorologiumTests.xctest')
(root/'Horologium.xcodeproj/xcshareddata/xcschemes/Horologium.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Horologium.xcodeproj')
