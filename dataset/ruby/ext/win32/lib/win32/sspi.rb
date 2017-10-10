
require 'Win32API'

module Win32
	module SSPI
		SECPKG_CRED_INBOUND = 0x00000001
		SECPKG_CRED_OUTBOUND = 0x00000002
		SECPKG_CRED_BOTH = 0x00000003

		SECURITY_NATIVE_DREP = 0x00000010
		SECURITY_NETWORK_DREP = 0x00000000

		ISC_REQ_REPLAY_DETECT = 0x00000004
		ISC_REQ_SEQUENCE_DETECT = 0x00000008
		ISC_REQ_CONFIDENTIALITY = 0x00000010
		ISC_REQ_USE_SESSION_KEY = 0x00000020
		ISC_REQ_PROMPT_FOR_CREDS = 0x00000040
		ISC_REQ_CONNECTION = 0x00000800

		module API
			AcquireCredentialsHandle = Win32API.new("secur32", "AcquireCredentialsHandle", 'ppLpppppp', 'L')
			InitializeSecurityContext = Win32API.new("secur32", "InitializeSecurityContext", 'pppLLLpLpppp', 'L')
			DeleteSecurityContext = Win32API.new("secur32", "DeleteSecurityContext", 'P', 'L')
			FreeCredentialsHandle = Win32API.new("secur32", "FreeCredentialsHandle", 'P', 'L')
		end

		class SecurityHandle
			def upper
				@struct.unpack("LL")[1]
			end

			def lower
				@struct.unpack("LL")[0]
			end

			def to_p
				@struct ||= "\0" * 8
			end
		end

		CredHandle = CtxtHandle = SecurityHandle

		class TimeStamp
			attr_reader :struct

			def to_p
				@struct ||= "\0" * 8
			end
		end

		class SecurityBuffer

			SECBUFFER_TOKEN = 2   # Security token

			TOKENBUFSIZE = 12288
			SECBUFFER_VERSION = 0

			def initialize(buffer = nil)
				@buffer = buffer || "\0" * TOKENBUFSIZE
				@bufferSize = @buffer.length
				@type = SECBUFFER_TOKEN
			end

			def bufferSize
				unpack
				@bufferSize
			end

			def bufferType
				unpack
				@type
			end

			def token
				unpack
				@buffer
			end

			def to_p
				@unpacked = nil
				@sec_buffer ||= [@bufferSize, @type, @buffer].pack("LLP")
				@struct ||= [SECBUFFER_VERSION, 1, @sec_buffer].pack("LLP")
			end

		private

			def unpack
				if ! @unpacked && @sec_buffer && @struct
					@bufferSize, @type = @sec_buffer.unpack("LL")
					@buffer = @sec_buffer.unpack("LLP#{@bufferSize}")[2]
					@struct = nil
					@sec_buffer = nil
					@unpacked = true
				end
			end
		end

		class Identity
			SEC_WINNT_AUTH_IDENTITY_ANSI = 0x1

			attr_accessor :user, :domain, :password

			def initialize(user = nil, domain = nil, password = nil)
				@user = user
				@domain = domain
				@password = password
				@flags = SEC_WINNT_AUTH_IDENTITY_ANSI
			end

			def to_p
				[@user, @user ? @user.length : 0,
				 @domain, @domain ? @domain.length : 0,
				 @password, @password ? @password.length : 0,
				 @flags].pack("PLPLPLL")
			end
		end

		class SSPIResult
			SEC_E_OK = 0x00000000
			SEC_I_CONTINUE_NEEDED = 0x00090312

			SEC_E_INSUFFICIENT_MEMORY = 0x80090300
			SEC_E_INTERNAL_ERROR = 0x80090304
			SEC_E_INVALID_HANDLE = 0x80090301
			SEC_E_INVALID_TOKEN = 0x80090308
			SEC_E_LOGON_DENIED = 0x8009030C
			SEC_E_NO_AUTHENTICATING_AUTHORITY = 0x80090311
			SEC_E_NO_CREDENTIALS = 0x8009030E
			SEC_E_TARGET_UNKNOWN = 0x80090303
			SEC_E_UNSUPPORTED_FUNCTION = 0x80090302
			SEC_E_WRONG_PRINCIPAL = 0x80090322

			SEC_E_NOT_OWNER = 0x80090306
			SEC_E_SECPKG_NOT_FOUND = 0x80090305
			SEC_E_UNKNOWN_CREDENTIALS = 0x8009030D

			@@map = {}
                        #nodyna <const_get-1511> <CG MODERATE (array)>
			constants.each { |v| @@map[self.const_get(v.to_s)] = v }

			attr_reader :value

			def initialize(value)
				value = [value].pack("L").unpack("L").first
				raise "#{value.to_s(16)} is not a recognized result" unless @@map.has_key? value
				@value = value
			end

			def to_s
				@@map[@value].to_s
			end

			def ok?
				@value == SEC_I_CONTINUE_NEEDED || @value == SEC_E_OK
			end

			def ==(other)
				if other.is_a?(SSPIResult)
					@value == other.value
				elsif other.is_a?(Fixnum)
					@value == @@map[other]
				else
					false
				end
			end
		end

		class NegotiateAuth
			attr_accessor :credentials, :context, :contextAttributes, :user, :domain

			REQUEST_FLAGS = ISC_REQ_CONFIDENTIALITY | ISC_REQ_REPLAY_DETECT | ISC_REQ_CONNECTION

      B64_TOKEN_PREFIX = ["NTLMSSP"].pack("m").delete("=\n")

			def NegotiateAuth.proxy_auth_get(http, path, user = nil, domain = nil)
				raise "http must respond to :get" unless http.respond_to?(:get)
				nego_auth = self.new user, domain

				resp = http.get path, { "Proxy-Authorization" => "Negotiate " + nego_auth.get_initial_token }
				if resp["Proxy-Authenticate"]
					resp = http.get path, { "Proxy-Authorization" => "Negotiate " + nego_auth.complete_authentication(resp["Proxy-Authenticate"].split(" ").last.strip) }
				end

				resp
			end

			def initialize(user = nil, domain = nil)
				if user.nil? && domain.nil? && ENV["USERNAME"].nil? && ENV["USERDOMAIN"].nil?
					raise "A username or domain must be supplied since they cannot be retrieved from the environment"
				end

				@user = user || ENV["USERNAME"]
				@domain = domain || ENV["USERDOMAIN"]
			end

			def get_initial_token
				raise "This object is no longer usable because its resources have been freed." if @cleaned_up
				get_credentials

				outputBuffer = SecurityBuffer.new
				@context = CtxtHandle.new
				@contextAttributes = "\0" * 4

				result = SSPIResult.new(API::InitializeSecurityContext.call(@credentials.to_p, nil, nil,
					REQUEST_FLAGS,0, SECURITY_NETWORK_DREP, nil, 0, @context.to_p, outputBuffer.to_p, @contextAttributes, TimeStamp.new.to_p))

				if result.ok? then
					return encode_token(outputBuffer.token)
				else
					raise "Error: #{result.to_s}"
				end
			end

			def complete_authentication(token)
				raise "This object is no longer usable because its resources have been freed." if @cleaned_up

				token = "" if token.nil?

				if token.include? "Negotiate"
					token = token.split(" ").last
				end

				if token.include? B64_TOKEN_PREFIX
          token = token.strip.unpack("m")[0]
				end

				outputBuffer = SecurityBuffer.new
				result = SSPIResult.new(API::InitializeSecurityContext.call(@credentials.to_p, @context.to_p, nil,
					REQUEST_FLAGS, 0, SECURITY_NETWORK_DREP, SecurityBuffer.new(token).to_p, 0,
					@context.to_p,
					outputBuffer.to_p, @contextAttributes, TimeStamp.new.to_p))

				if result.ok? then
					return encode_token(outputBuffer.token)
				else
					raise "Error: #{result.to_s}"
				end
			ensure
				clean_up unless @cleaned_up
			end

		 private

			def clean_up
				@cleaned_up = true
				API::FreeCredentialsHandle.call(@credentials.to_p)
				API::DeleteSecurityContext.call(@context.to_p)
				@context = nil
				@credentials = nil
				@contextAttributes = nil
			end

			def get_credentials
				@credentials = CredHandle.new
				ts = TimeStamp.new
				@identity = Identity.new @user, @domain
				result = SSPIResult.new(API::AcquireCredentialsHandle.call(nil, "Negotiate", SECPKG_CRED_OUTBOUND, nil, @identity.to_p,
					nil, nil, @credentials.to_p, ts.to_p))
				raise "Error acquire credentials: #{result}" unless result.ok?
			end

			def encode_token(t)
        [t].pack("m").delete("\n")
			end
		end
	end
end
