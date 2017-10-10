module Gem::Security


  NoSecurity = Policy.new(
    'No Security',
    :verify_data      => false,
    :verify_signer    => false,
    :verify_chain     => false,
    :verify_root      => false,
    :only_trusted     => false,
    :only_signed      => false
  )


  AlmostNoSecurity = Policy.new(
    'Almost No Security',
    :verify_data      => true,
    :verify_signer    => false,
    :verify_chain     => false,
    :verify_root      => false,
    :only_trusted     => false,
    :only_signed      => false
  )


  LowSecurity = Policy.new(
    'Low Security',
    :verify_data      => true,
    :verify_signer    => true,
    :verify_chain     => false,
    :verify_root      => false,
    :only_trusted     => false,
    :only_signed      => false
  )


  MediumSecurity = Policy.new(
    'Medium Security',
    :verify_data      => true,
    :verify_signer    => true,
    :verify_chain     => true,
    :verify_root      => true,
    :only_trusted     => true,
    :only_signed      => false
  )


  HighSecurity = Policy.new(
    'High Security',
    :verify_data      => true,
    :verify_signer    => true,
    :verify_chain     => true,
    :verify_root      => true,
    :only_trusted     => true,
    :only_signed      => true
  )


  SigningPolicy = Policy.new(
    'Signing Policy',
    :verify_data      => false,
    :verify_signer    => true,
    :verify_chain     => true,
    :verify_root      => true,
    :only_trusted     => false,
    :only_signed      => false
  )


  Policies = {
    'NoSecurity'       => NoSecurity,
    'AlmostNoSecurity' => AlmostNoSecurity,
    'LowSecurity'      => LowSecurity,
    'MediumSecurity'   => MediumSecurity,
    'HighSecurity'     => HighSecurity,
  }

end

