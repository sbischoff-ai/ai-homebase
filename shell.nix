{ pkgs ? import <nixpkgs> {}, profile ? "dev" }:
let
  commonPackages = with pkgs; [
    kubernetes-helm
    kubectl
    k3d
    incus
    docker-client
    gnumake
    python3
    curl
    jq
    yq-go
  ];

  shells = {
    dev = pkgs.mkShell {
      packages = commonPackages;

      shellHook = ''
        export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

        echo "ai-homebase nix-shell profile: dev"
        echo "Available tools: helm, kubectl, k3d, incus, docker, make, python3, curl, jq, yq"
        echo "Tip: k3d requires a running Docker daemon (check: docker info)"
        echo "Use --argstr profile devops to add Azure deployment tooling"
      '';
    };

    devops = pkgs.mkShell {
      packages = commonPackages ++ (with pkgs; [
        azure-cli
        kubelogin
      ]);

      shellHook = ''
        export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

        echo "ai-homebase nix-shell profile: devops"
        echo "Available tools: helm, kubectl, k3d, incus, docker, make, python3, curl, jq, yq, az, kubelogin"
        echo "Tip: k3d requires a running Docker daemon (check: docker info)"
      '';
    };
  };
in
  shells.${profile}
