require 'xcodeproj'

project_path = '/Users/jasonalaounis/PhotoCoachPro/PhotoCoachPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'PhotoCoachPro' }
raise 'App target not found' unless app_target

# Create the unit test bundle target (platform :osx)
test_target = project.new_target(
  :unit_test_bundle,
  'PhotoCoachProTests',
  :osx,
  '14.0'
)

# Wire host app so @testable import PhotoCoachPro works
test_target.build_configurations.each do |config|
  config.build_settings['BUNDLE_LOADER']            = '$(TEST_HOST)'
  config.build_settings['TEST_HOST']                = '$(BUILT_PRODUCTS_DIR)/PhotoCoachPro.app/Contents/MacOS/PhotoCoachPro'
  config.build_settings['SWIFT_VERSION']            = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['GENERATE_INFOPLIST_FILE']  = 'YES'
  config.build_settings['PRODUCT_NAME']             = 'PhotoCoachProTests'
  config.build_settings['PRODUCT_MODULE_NAME']      = 'PhotoCoachProTests'
end

# Explicit dependency: app builds before tests
test_target.add_dependency(app_target)

# Create Tests group (maps to PhotoCoachProTests/ folder)
tests_group = project.main_group.new_group('PhotoCoachProTests', 'PhotoCoachProTests')

# Register each test file
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
puts 'Test target added successfully.'
