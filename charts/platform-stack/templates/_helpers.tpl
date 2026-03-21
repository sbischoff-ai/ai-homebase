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
{{- coalesce .Values.certManager.resourceNamespace .Values.certManagerChart.clusterResourceNamespace .Values.certManagerChart.namespace .Release.Namespace -}}
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
