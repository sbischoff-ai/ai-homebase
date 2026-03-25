{{- define "nextcloud-mcp.name" -}}
{{- default (.Chart.Name | kebabcase) .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nextcloud-mcp.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "nextcloud-mcp.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{ define "nextcloud-mcp.labels" }}
app.kubernetes.io/name: {{ include "nextcloud-mcp.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ with .Values.global.commonLabels }}
{{ toYaml . }}
{{ end }}
{{ end }}

{{- define "nextcloud-mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nextcloud-mcp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
