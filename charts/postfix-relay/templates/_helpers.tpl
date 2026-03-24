{{- define "postfix-relay.name" -}}
{{- default (.Chart.Name | kebabcase) .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "postfix-relay.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "postfix-relay.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "postfix-relay.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "postfix-relay.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "postfix-relay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postfix-relay.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "postfix-relay.allowedSenderDomains" -}}
{{- if .Values.config.allowedSenderDomains -}}
{{- .Values.config.allowedSenderDomains -}}
{{- else -}}
{{- .Values.global.mail.domain | default "" -}}
{{- end -}}
{{- end -}}

{{- define "postfix-relay.hostname" -}}
{{- if .Values.config.hostname -}}
{{- .Values.config.hostname -}}
{{- else -}}
{{- .Values.global.mail.smtpHost | default (include "postfix-relay.fullname" .) -}}
{{- end -}}
{{- end -}}
