{ stdenv, buildGoModule, fetchFromGitHub, fetchpatch }:

buildGoModule rec {
  pname = "sops";
  version = "3.6.0";

  src = fetchFromGitHub {
    rev = "5f7d32404639855ee4f35f187714d71fc43aa4fa";
    owner = "mozilla";
    repo = pname;
    sha256 = "01skk6vdfki4a88z0snl1pby09im406qhnsfa0d2l8gp6nz8pq6j";
  };

  patches = [ (fetchpatch {
      url = "https://patch-diff.githubusercontent.com/raw/mozilla/sops/pull/688.patch";
      sha256 = "132cfaf20j1vip48gyx0lvwk4r54cjbfxb7gpxfziq4x86bgqjn6";
    })
  ];

  vendorSha256 = "1s04dzfivxbw9hxlma9w7qs4vmdca57kl5b55y6id3xk7xq17gxc";

  meta = with stdenv.lib; {
    homepage = "https://github.com/mozilla/sops";
    description = "Mozilla sops (Secrets OPerationS) is an editor of encrypted files";
    maintainers = [ maintainers.marsam ];
    license = licenses.mpl20;
  };
}
