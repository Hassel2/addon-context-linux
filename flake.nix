{
    description = "This addon provides contextualization packages for the Linux (and, other Unix-like) guest virtual machines running in the OpenNebula cloud.";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    };

    outputs = inputs @ {
        self,
        nixpkgs,
        ...
    }: 
    {
	defaultPackage.x86_64-linux =
	    with import nixpkgs { system = "x86_64-linux"; };
	    stdenv.mkDerivation {
                pname = "one-context";
                version = "6.6.1";

                src = self;

                builder = ./generate-nix.sh;
	    };
    };
}
