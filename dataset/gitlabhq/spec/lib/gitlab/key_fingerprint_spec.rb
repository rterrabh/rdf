require "spec_helper"

describe Gitlab::KeyFingerprint do
  let(:key)         { "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAiPWx6WM4lhHNedGfBpPJNPpZ7yKu+dnn1SJejgt4596k6YjzGGphH2TUxwKzxcKDKKezwkpfnxPkSMkuEspGRt/aZZ9wa++Oi7Qkr8prgHc4soW6NUlfDzpvZK2H5E7eQaSeP3SAwGmQKUFHCddNaP0L+hM7zhFNzjFvpaMgJw0=" }
  let(:fingerprint) { "3f:a2:ee:de:b5:de:53:c3:aa:2f:9c:45:24:4c:47:7b" }

  describe "#fingerprint" do
    it "generates the key's fingerprint" do
      expect(Gitlab::KeyFingerprint.new(key).fingerprint).to eq(fingerprint)
    end
  end
end
