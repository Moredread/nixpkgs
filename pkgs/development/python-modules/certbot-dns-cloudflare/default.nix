{
  buildPythonPackage,
  acme,
  certbot,
  cloudflare,
  pytestCheckHook,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "certbot-dns-cloudflare";
  format = "setuptools";

  inherit (certbot) src version;
  disabled = pythonOlder "3.6";

  sourceRoot = "${src.name}/certbot-dns-cloudflare";

  propagatedBuildInputs = [
    acme
    certbot
    cloudflare
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  pytestFlagsArray = [
    "-p no:cacheprovider"

    # Monitor https://github.com/certbot/certbot/issues/9606 for a solution
    "-W"
    "ignore::DeprecationWarning"
  ];

  meta = certbot.meta // {
    description = "Cloudflare DNS Authenticator plugin for Certbot";
  };
}
