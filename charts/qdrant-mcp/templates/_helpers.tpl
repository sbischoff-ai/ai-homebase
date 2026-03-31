{{- define "qdrant-mcp.name" -}}
{{- default (.Chart.Name | kebabcase) .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "qdrant-mcp.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "qdrant-mcp.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "qdrant-mcp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "qdrant-mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qdrant-mcp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "qdrant-mcp.labels" -}}
helm.sh/chart: {{ include "qdrant-mcp.chart" . | kebabcase }}
{{ include "qdrant-mcp.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
