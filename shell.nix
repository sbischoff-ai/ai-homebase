{ pkgs ? import <nixpkgs> {}, profile ? "dev" }:
let
  commonPackages = with pkgs; [
    kubernetes-helm
    kubectl
    k3d
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
        echo "Available tools: helm, kubectl, k3d, docker, make, python3, curl, jq, yq"
        echo "Tip: install Incus separately on the host if you want the bootstrap-managed sandbox VM"
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
        echo "Available tools: helm, kubectl, k3d, docker, make, python3, curl, jq, yq, az, kubelogin"
        echo "Tip: install Incus separately on the host if you want the bootstrap-managed sandbox VM"
        echo "Tip: k3d requires a running Docker daemon (check: docker info)"
      '';
    };
  };
in
  shells.${profile}
