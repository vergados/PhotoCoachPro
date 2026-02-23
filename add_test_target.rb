require 'xcodeproj'
require 'fileutils'

project_path = '/Users/jasonalaounis/PhotoCoachPro/PhotoCoachPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'PhotoCoachPro' }
raise 'App target not found' unless app_target

# Enable testability on the app so @testable import works
app_target.build_configurations.each do |config|
  config.build_settings['ENABLE_TESTABILITY'] = 'YES' if config.name == 'Debug'
end

# Skip if test target already exists
if project.targets.any? { |t| t.name == 'PhotoCoachProTests' }
  puts 'Test target already exists, skipping.'
  exit 0
end

# Create the unit test bundle target
test_target = project.new_target(
  :unit_test_bundle,
  'PhotoCoachProTests',
  :osx,
  '14.0'
)

test_target.build_configurations.each do |config|
  config.build_settings['BUNDLE_LOADER']                       = '$(TEST_HOST)'
  config.build_settings['TEST_HOST']                           = '$(BUILT_PRODUCTS_DIR)/PhotoCoachPro.app/Contents/MacOS/PhotoCoachPro'
  config.build_settings['SWIFT_VERSION']                       = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET']            = '14.0'
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
end

# Explicit dependency: app builds before tests
test_target.add_dependency(app_target)

# Create Tests group
tests_group = project.main_group.new_group('PhotoCoachProTests', 'PhotoCoachProTests')

%w[
  ExportSettingsTests.swift
  CritiqueResultTests.swift
  WeeklyFocusPlanTests.swift
  SkillHistoryTests.swift
].each do |filename|
  ref = tests_group.new_file(filename)
  test_target.source_build_phase.add_file_reference(ref)
end

project.save
puts "Test target added. UUID: #{test_target.uuid}"

# Write xcscheme so xcodebuild -scheme PhotoCoachProTests works
target_uuid = test_target.uuid
schemes_dir = "#{project_path}/xcshareddata/xcschemes"
FileUtils.mkdir_p(schemes_dir)

scheme_xml = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <Scheme LastUpgradeVersion="1500" version="1.7">
    <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
        <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">
          <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target_uuid}" BuildableName="PhotoCoachProTests.xctest" BlueprintName="PhotoCoachProTests" ReferencedContainer="container:PhotoCoachPro.xcodeproj"/>
        </BuildActionEntry>
      </BuildActionEntries>
    </BuildAction>
    <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" codeCoverageEnabled="NO">
      <Testables>
        <TestableReference skipped="NO">
          <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target_uuid}" BuildableName="PhotoCoachProTests.xctest" BlueprintName="PhotoCoachProTests" ReferencedContainer="container:PhotoCoachPro.xcodeproj"/>
        </TestableReference>
      </Testables>
    </TestAction>
    <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
    <AnalyzeAction buildConfiguration="Debug"/>
    <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
  </Scheme>
XML

File.write("#{schemes_dir}/PhotoCoachProTests.xcscheme", scheme_xml)
puts "Scheme written to #{schemes_dir}/PhotoCoachProTests.xcscheme"
