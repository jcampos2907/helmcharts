{{/*
Expand the name of the chart.
*/}}
{{- define "ravenhold.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ravenhold.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "ravenhold.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. Call with (dict "ctx" . "component" "api").
*/}}
{{- define "ravenhold.labels" -}}
app.kubernetes.io/name: {{ include "ravenhold.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
helm.sh/chart: {{ include "ravenhold.chart" .ctx }}
{{- end }}

{{/*
Selector labels. Call with (dict "ctx" . "component" "api").
*/}}
{{- define "ravenhold.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ravenhold.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Image reference; an empty tag falls back to the Chart appVersion. Call with (dict "image" .Values.api.image "ctx" .).
*/}}
{{- define "ravenhold.image" -}}
{{- printf "%s:%s" .image.repository (default .ctx.Chart.AppVersion .image.tag) }}
{{- end }}

{{/*
Environment of the api container and the migration Job: plain values, then every key of the existing Secret.
The Job deliberately never sets Migrations__RunOnBoot, so the boot block (migrations) runs in it.
*/}}
{{- define "ravenhold.apiEnv" -}}
{{- range $k, $v := .Values.api.env }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- if .Values.ibGateway.live.enabled }}
- name: GatewayScreen__Live__Host
  value: {{ include "ravenhold.fullname" . }}-ib-gateway
- name: GatewayScreen__Live__Port
  value: "5900"
{{- end }}
{{- if .Values.ibGateway.paper.enabled }}
- name: GatewayScreen__Paper__Host
  value: {{ include "ravenhold.fullname" . }}-ib-gateway-paper
- name: GatewayScreen__Paper__Port
  value: "5900"
{{- end }}
{{- end }}
