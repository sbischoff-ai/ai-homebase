{{- define "platform-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-stack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "platform-stack.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "platform-stack.labels" -}}
app.kubernetes.io/name: {{ include "platform-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "platform-stack.certManagerResourceNamespace" -}}
{{- $certManagerValues := index .Values "cert-manager" | default (dict) -}}
{{- coalesce .Values.certManager.resourceNamespace (get $certManagerValues "clusterResourceNamespace") (get $certManagerValues "namespace") .Release.Namespace -}}
{{- end -}}

{{- define "platform-stack.openclawIngressHost" -}}
{{- $globalHost := .Values.global.hosts.openclaw | default "" -}}
{{- $defaultHost := .Values.openclaw.ingress.defaultHost | default "" -}}
{{- $hosts := .Values.openclaw.ingress.hosts | default (list) -}}
{{- $firstHost := "" -}}
{{- if and (kindIs "slice" $hosts) (gt (len $hosts) 0) -}}
  {{- $firstHost = default "" (get (index $hosts 0) "host") -}}
{{- end -}}
{{- coalesce $firstHost $defaultHost $globalHost -}}
{{- end -}}

{{- define "platform-stack.openclawTlsSecretName" -}}
{{- $tls := .Values.openclaw.ingress.tls | default (list) -}}
{{- $secretName := "" -}}
{{- if and (kindIs "slice" $tls) (gt (len $tls) 0) -}}
  {{- $secretName = default "" (get (index $tls 0) "secretName") -}}
{{- end -}}
{{- $secretName -}}
{{- end -}}


{{- define "platform-stack.sharedPostgresqlFullname" -}}
{{- if .Values.sharedPostgresql.fullnameOverride -}}
{{- .Values.sharedPostgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-shared-postgresql" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "platform-stack.sharedPostgresqlBootstrapEnabled" -}}
{{- if and .Values.sharedPostgresql.enabled (or .Values.gitea.enabled .Values.vaultwarden.enabled .Values.nextcloud.enabled .Values.paperlessNgx.enabled) -}}true{{- end -}}
{{- end -}}

{{- define "platform-stack.sharedPostgresqlBootstrapJobName" -}}
{{- printf "%s-bootstrap" (include "platform-stack.sharedPostgresqlFullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-stack.memgraphServiceHost" -}}
{{- if .Values.memgraph.fullnameOverride -}}
{{- .Values.memgraph.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-memgraph" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
