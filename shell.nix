{ pkgs ? import <nixpkgs> {}, profile ? "dev" }:
let
  commonPackages = with pkgs; [
    kubernetes-helm
    kubectl
    k3d
    docker-client
    jq
    yq-go
  ];

  shells = {
    dev = pkgs.mkShell {
      packages = commonPackages;

      shellHook = ''
        export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

        echo "ai-homebase nix-shell profile: dev"
        echo "Available tools: helm, kubectl, k3d, docker, jq, yq"
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
        echo "Available tools: helm, kubectl, k3d, docker, jq, yq, az, kubelogin"
      '';
    };
  };
in
  shells.${profile}
