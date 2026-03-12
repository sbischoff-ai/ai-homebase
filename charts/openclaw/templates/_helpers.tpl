{{- define "openclaw.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openclaw.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "openclaw.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openclaw.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "openclaw.labels" -}}
helm.sh/chart: {{ include "openclaw.chart" . }}
{{ include "openclaw.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "openclaw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "openclaw.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "openclaw.effectiveImagePullSecrets" -}}
{{- $global := .Values.global.imagePullSecrets | default (list) -}}
{{- $local := .Values.imagePullSecrets | default (list) -}}
{{- concat $global $local | uniq | toYaml -}}
{{- end -}}

{{- define "openclaw.effectiveStorageClass" -}}
{{- if .Values.persistence.storageClass -}}
{{- .Values.persistence.storageClass -}}
{{- else -}}
{{- .Values.global.storageClass -}}
{{- end -}}
{{- end -}}
