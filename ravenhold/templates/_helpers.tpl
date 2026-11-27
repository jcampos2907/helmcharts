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
{{- $repo := .image.repository | default (printf "%s/%s" .ctx.Values.registry .component) }}
{{- printf "%s:%s" $repo (default .ctx.Chart.AppVersion .image.tag) }}
{{- end }}

{{/*
The migration Job's image: its own repository/tag when set, otherwise exactly the api image.
*/}}
{{- define "ravenhold.migrationsImage" -}}
{{- $img := dict "repository" (.Values.migrations.image.repository | default .Values.api.image.repository) "tag" (.Values.migrations.image.tag | default .Values.api.image.tag) }}
{{- include "ravenhold.image" (dict "image" $img "ctx" . "component" "api") }}
{{- end }}

{{/*
Database credentials as env vars, for the $(DB_USER)/$(DB_PASSWORD) references below. Empty without database.existingSecret.
*/}}
{{- define "ravenhold.dbCreds" -}}
{{- with .Values.database.existingSecret }}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ . }}
      key: {{ $.Values.database.usernameKey }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ . }}
      key: {{ $.Values.database.passwordKey }}
{{- end }}
{{- end }}

{{/*
Environment of the api container and the migration Job: plain values, then every key of the existing Secret.
The Job deliberately never sets Migrations__RunOnBoot, so the boot block (migrations) runs in it.
*/}}
{{- define "ravenhold.apiEnv" -}}
{{- if .Values.database.existingSecret }}
{{- include "ravenhold.dbCreds" . }}
- name: ConnectionStrings__Default
  value: {{ printf "Host=%s;Port=%v;Database=%s;Username=$(DB_USER);Password=$(DB_PASSWORD);SSL Mode=%s" (required "database.host is required with database.existingSecret" .Values.database.host) .Values.database.port .Values.database.name (.Values.database.sslMode | title) | quote }}
{{- end }}
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

{{/*
The analytics ServiceAccount: the identity Anthropic workload identity federation trusts (the rule's subject is
system:serviceaccount:<namespace>:<this name>). The api pod runs as it too when api.anthropicFederation.enabled.
*/}}
{{- define "ravenhold.analyticsServiceAccountName" -}}
{{- include "ravenhold.fullname" . }}-analytics
{{- end }}

{{/*
Anthropic workload identity federation, shared by analytics and the api so both use exactly the same token file,
audience and IDs (all from analytics.anthropicFederation). Env entries, the volumeMount and the projected volume.
*/}}
{{- define "ravenhold.anthropicFederationEnv" -}}
{{- with .Values.analytics.anthropicFederation -}}
- name: ANTHROPIC_IDENTITY_TOKEN_FILE
  value: /var/run/secrets/anthropic.com/token
- name: ANTHROPIC_FEDERATION_RULE_ID
  value: {{ required "analytics.anthropicFederation.ruleId is required when enabled" .ruleId | quote }}
- name: ANTHROPIC_ORGANIZATION_ID
  value: {{ required "analytics.anthropicFederation.organizationId is required when enabled" .organizationId | quote }}
{{- if .serviceAccountId }}
- name: ANTHROPIC_SERVICE_ACCOUNT_ID
  value: {{ .serviceAccountId | quote }}
{{- end }}
{{- if .workspaceId }}
- name: ANTHROPIC_WORKSPACE_ID
  value: {{ .workspaceId | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ravenhold.anthropicFederationMount" -}}
- name: anthropic-token
  mountPath: /var/run/secrets/anthropic.com
  readOnly: true
{{- end }}

{{- define "ravenhold.anthropicFederationVolume" -}}
- name: anthropic-token
  projected:
    sources:
      - serviceAccountToken:
          audience: {{ .Values.analytics.anthropicFederation.audience | quote }}
          expirationSeconds: {{ .Values.analytics.anthropicFederation.expirationSeconds }}
          path: token
{{- end }}

{{/*
Environment shared by the analytics Deployment and the bootstrap Job: the plain analytics.env values, the database
URL with its credentials, and the Anthropic federation variables. RSSHUB_URL is added by the Deployment alone
(the Job has no RSSHub sidecar). The IBKR variables follow in "ravenhold.analyticsIbEnv".
*/}}
{{- define "ravenhold.analyticsEnv" -}}
{{- range $k, $v := .Values.analytics.env }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- if .Values.database.existingSecret }}
{{- include "ravenhold.dbCreds" . }}
- name: DATABASE_URL
  value: {{ printf "postgresql://$(DB_USER):$(DB_PASSWORD)@%s:%v/%s?sslmode=%s" .Values.database.host .Values.database.port .Values.database.name .Values.database.sslMode | quote }}
{{- end }}
{{- if .Values.analytics.anthropicFederation.enabled }}
{{- /* Workload identity federation: the SDK exchanges the projected token for an Anthropic access token.
       An ANTHROPIC_API_KEY in the secret still wins over this. */}}
{{ include "ravenhold.anthropicFederationEnv" . }}
{{- end }}
{{- end }}

{{/*
The IB Gateway endpoints analytics connects to, for whichever gateways are enabled.
*/}}
{{- define "ravenhold.analyticsIbEnv" -}}
{{- if .Values.ibGateway.live.enabled }}
- name: IBKR_HOST
  value: {{ include "ravenhold.fullname" . }}-ib-gateway
- name: IBKR_PORT
  value: "4003"
{{- end }}
{{- if .Values.ibGateway.paper.enabled }}
- name: IBKR_PAPER_HOST
  value: {{ include "ravenhold.fullname" . }}-ib-gateway-paper
- name: IBKR_PAPER_PORT
  value: "4004"
{{- end }}
{{- end }}

{{/*
The bootstrap Job's name: suffixed with a short hash of the analytics image, so every new image renders a new Job
(a Job's pod template is immutable) while the same image renders the same name (never .Release.Revision).
NOTES.txt uses this same template for the log command.
*/}}
{{- define "ravenhold.bootstrapJobName" -}}
{{- $image := include "ravenhold.image" (dict "image" .Values.analytics.image "ctx" . "component" "analytics") }}
{{- printf "%s-bootstrap-%s" (include "ravenhold.fullname" . | trunc 44 | trimSuffix "-") (sha256sum $image | trunc 8) }}
{{- end }}
