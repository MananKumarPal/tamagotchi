# Adds the WidgetKit extension target to the Runner project. Safe to re-run.
# Run from the repo root: ruby tool/add_ios_widget.rb
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
team = runner.build_configurations.first.build_settings['DEVELOPMENT_TEAM'] ||
       project.build_configurations.first.build_settings['DEVELOPMENT_TEAM']

widget = project.targets.find { |t| t.name == 'EgglingWidget' }
unless widget
  widget = project.new_target(:app_extension, 'EgglingWidget', :ios, '17.0')
  group = project.main_group.new_group('EgglingWidget', 'EgglingWidget')
  shared = project.main_group.new_group('Shared', 'Shared')
  widget_swift = group.new_file('EgglingWidget.swift')
  group.new_file('Info.plist')
  group.new_file('EgglingWidget.entitlements')
  store = shared.new_file('WidgetStore.swift')
  widget.add_file_references([widget_swift, store])
  runner.source_build_phase.add_file_reference(store)
  runner.add_dependency(widget)

  embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed.name = 'Embed Foundation Extensions'
  embed.symbol_dst_subfolder_spec = :plug_ins
  build_file = embed.add_file_reference(widget.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  # Must run before Flutter's Thin Binary script or Xcode reports a cycle.
  thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
  runner.build_phases.insert(thin || runner.build_phases.length, embed)
end

widget.build_configurations.each do |config|
  flutter = runner.build_configurations.find { |c| c.name == config.name }
  config.base_configuration_reference = flutter.base_configuration_reference
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.manankumar.eggling.widget',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'EgglingWidget/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => 'EgglingWidget/EgglingWidget.entitlements',
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => team,
    'SWIFT_VERSION' => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    'SKIP_INSTALL' => 'YES',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO'
  )
end

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
