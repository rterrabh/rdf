module Pod
  module Generator
    class InfoPlistFile
      attr_reader :target

      def initialize(target)
        @target = target
      end

      def save_as(path)
        contents = generate
        path.open('w') do |f|
          f.write(contents)
        end
      end

      def target_version
        if target && target.respond_to?(:root_spec)
          target.root_spec.version.to_s
        else
          '1.0.0'
        end
      end

      def generate
        FILE_CONTENTS.sub('${CURRENT_PROJECT_VERSION_STRING}', target_version)
      end

      FILE_CONTENTS = <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>org.cocoapods.${PRODUCT_NAME:rfc1034identifier}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>${CURRENT_PROJECT_VERSION_STRING}</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>${CURRENT_PROJECT_VERSION}</string>
  <key>NSPrincipalClass</key>
  <string></string>
</dict>
</plist>
      EOS
    end
  end
end
