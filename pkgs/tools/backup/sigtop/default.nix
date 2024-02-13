{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  name = "sigtop";
  version = "0.9.1";

  src = fetchFromGitHub {
    owner = "tbvdm";
    repo = "sigtop";
    rev = "v${version}";
    sha256 = "sha256-2qV+m9Bxhq9l27w1Xt8x8ah+QffRHkXHh2PqWdKkFaA=";
  };

  vendorHash = "sha256-kkRmyWYrWDq96fECe2YMsDjRZPX2K0jKFitMJycaVVA=";

  makeFlags = [
    "PREFIX=\${out}"
  ];

  meta = with lib; {
    description = "Utility to export messages, attachments and other data from Signal Desktop";
    license = licenses.isc;
    platforms = platforms.all;
    maintainers = with maintainers; [ fricklerhandwerk ];
  };
}
