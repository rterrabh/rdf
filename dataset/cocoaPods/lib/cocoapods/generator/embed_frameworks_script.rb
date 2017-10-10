module Pod
  module Generator
    class EmbedFrameworksScript
      attr_reader :frameworks_by_config

      def initialize(frameworks_by_config)
        @frameworks_by_config = frameworks_by_config
      end

      def save_as(pathname)
        pathname.open('w') do |file|
          file.puts(script)
        end
        File.chmod(0755, pathname.to_s)
      end

      private


      def script
        script = <<-SH.strip_heredoc
          set -e

          echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
          mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

          SWIFT_STDLIB_PATH="${DT_TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"

          install_framework()
          {
            if [ -r "${BUILT_PRODUCTS_DIR}/$1" ]; then
              local source="${BUILT_PRODUCTS_DIR}/$1"
            elif [ -r "${BUILT_PRODUCTS_DIR}/$(basename "$1")" ]; then
              local source="${BUILT_PRODUCTS_DIR}/$(basename "$1")"
            elif [ -r "$1" ]; then
              local source="$1"
            fi

            local destination="${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

            if [ -L "${source}" ]; then
                echo "Symlinked..."
                source="$(readlink "${source}")"
            fi

            echo "rsync -av --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" --filter \\"- Headers\\" --filter \\"- PrivateHeaders\\" --filter \\"- Modules\\" \\"${source}\\" \\"${destination}\\""
            rsync -av --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" --filter "- Headers" --filter "- PrivateHeaders" --filter "- Modules" "${source}" "${destination}"

            local basename
            basename="$(basename -s .framework "$1")"
            binary="${destination}/${basename}.framework/${basename}"
            if ! [ -r "$binary" ]; then
              binary="${destination}/${basename}"
            fi

            if [[ "$(file "$binary")" == *"dynamically linked shared library"* ]]; then
              strip_invalid_archs "$binary"
            fi

            code_sign_if_enabled "${destination}/$(basename "$1")"

            local swift_runtime_libs
            swift_runtime_libs=$(xcrun otool -LX "$binary" | grep --color=never @rpath/libswift | sed -E s/@rpath\\\\/\\(.+dylib\\).*/\\\\1/g | uniq -u  && exit ${PIPESTATUS[0]})
            for lib in $swift_runtime_libs; do
              echo "rsync -auv \\"${SWIFT_STDLIB_PATH}/${lib}\\" \\"${destination}\\""
              rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"
              code_sign_if_enabled "${destination}/${lib}"
            done
          }

          code_sign_if_enabled() {
            if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" -a "${CODE_SIGNING_REQUIRED}" != "NO" -a "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
              echo "Code Signing $1 with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
              echo "/usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --preserve-metadata=identifier,entitlements \\"$1\\""
              /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --preserve-metadata=identifier,entitlements "$1"
            fi
          }

          strip_invalid_archs() {
            binary="$1"
            archs="$(lipo -info "$binary" | rev | cut -d ':' -f1 | rev)"
            stripped=""
            for arch in $archs; do
              if ! [[ "${VALID_ARCHS}" == *"$arch"* ]]; then
                lipo -remove "$arch" -output "$binary" "$binary" || exit 1
                stripped="$stripped $arch"
              fi
            done
            if [[ "$stripped" ]]; then
              echo "Stripped $binary of architectures:$stripped"
            fi
          }

        SH
        script << "\n" unless frameworks_by_config.values.all?(&:empty?)
        frameworks_by_config.each do |config, frameworks|
          unless frameworks.empty?
            script << %(if [[ "$CONFIGURATION" == "#{config}" ]]; then\n)
            frameworks.each do |framework|
              script << %(  install_framework "#{framework}"\n)
            end
            script << "fi\n"
          end
        end
        script
      end
    end
  end
end
