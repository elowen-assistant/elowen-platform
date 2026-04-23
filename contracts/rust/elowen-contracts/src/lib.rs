//! Shared internal API-edge Rust message contracts.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Requested execution intent for a dispatched job.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionIntent {
    WorkspaceChange,
    ReadOnly,
}

impl ExecutionIntent {
    /// Returns the stable wire label used in prompts, summaries, and reports.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::WorkspaceChange => "workspace_change",
            Self::ReadOnly => "read_only",
        }
    }
}

/// Specialization for a dispatched job target.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum JobTargetKind {
    #[default]
    Repository,
    Capability,
}

impl JobTargetKind {
    /// Returns the stable wire label used in prompts, summaries, and reports.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Repository => "repository",
            Self::Capability => "capability",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct DeviceRepository {
    pub name: String,
    #[serde(default)]
    pub branches: Vec<String>,
}

/// Device registration payload sent to the orchestrator API.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RegisterDeviceRequest {
    pub name: String,
    pub primary_flag: bool,
    #[serde(default)]
    pub allowed_repos: Vec<String>,
    #[serde(default)]
    pub allowed_repo_roots: Vec<String>,
    #[serde(default)]
    pub hidden_repos: Vec<String>,
    #[serde(default)]
    pub excluded_repo_paths: Vec<String>,
    #[serde(default)]
    pub discovered_repos: Vec<String>,
    #[serde(default)]
    pub repositories: Vec<DeviceRepository>,
    #[serde(default)]
    pub capabilities: Vec<String>,
    #[serde(default)]
    pub trust: Option<DeviceRegistrationTrustProof>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OrchestratorTrustSigner {
    pub key_id: String,
    pub public_key: String,
    pub active: bool,
}

/// Orchestrator-signed challenge used before trusted registration.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RegistrationChallengeResponse {
    pub challenge_id: String,
    pub challenge: String,
    pub issued_at: DateTime<Utc>,
    #[serde(default)]
    pub orchestrator_key_id: Option<String>,
    pub orchestrator_public_key: String,
    #[serde(default)]
    pub trusted_signers: Vec<OrchestratorTrustSigner>,
    pub signature: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum RegistrationTrustIntent {
    #[default]
    Enroll,
    Rotate,
    Reenroll,
}

/// Edge-signed proof attached to trusted registration requests.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DeviceRegistrationTrustProof {
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub trusted_orchestrator_public_keys: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub trusted_orchestrator_key_ids: Option<Vec<String>>,
    pub orchestrator_key_id: String,
    pub orchestrator_challenge_id: String,
    pub orchestrator_challenge: String,
    pub orchestrator_challenge_issued_at: DateTime<Utc>,
    pub orchestrator_public_key: String,
    pub orchestrator_signature: String,
    pub edge_public_key: String,
    pub edge_signature: String,
    #[serde(default)]
    pub registration_intent: RegistrationTrustIntent,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub previous_edge_public_key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub previous_edge_signature: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reenrollment_kind: Option<String>,
}

/// Availability probe request sent via NATS request/reply.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AvailabilityProbeMessage {
    pub probe_id: String,
    pub job_id: Option<String>,
    pub device_id: String,
    pub sent_at: DateTime<Utc>,
}

/// Availability response returned by the edge.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AvailabilitySnapshot {
    pub probe_id: String,
    pub job_id: Option<String>,
    pub device_id: String,
    pub available: bool,
    pub reason: String,
    pub responded_at: DateTime<Utc>,
}

/// Dispatched execution request sent from the orchestrator to the edge.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JobDispatchMessage {
    pub job_id: String,
    pub short_id: String,
    pub correlation_id: String,
    pub thread_id: String,
    pub title: String,
    pub device_id: String,
    #[serde(default)]
    pub target_kind: JobTargetKind,
    pub target_name: String,
    pub base_branch: Option<String>,
    pub branch_name: Option<String>,
    #[serde(alias = "request_text")]
    pub prompt: String,
    pub execution_intent: ExecutionIntent,
    pub dispatched_at: DateTime<Utc>,
}

impl JobDispatchMessage {
    pub fn target_name(&self) -> &str {
        self.target_name.trim()
    }
}

/// Lifecycle event emitted by the edge back to the orchestrator.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct JobLifecycleEvent {
    pub job_id: String,
    pub correlation_id: String,
    pub device_id: String,
    pub event_type: String,
    pub status: Option<String>,
    pub result: Option<String>,
    pub failure_class: Option<String>,
    pub worktree_path: Option<String>,
    pub detail: Option<String>,
    pub payload_json: Option<Value>,
    pub created_at: DateTime<Utc>,
}

/// Approval command sent to the edge after a user approves a push.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JobApprovalCommand {
    pub approval_id: String,
    pub job_id: String,
    pub short_id: String,
    pub correlation_id: String,
    pub device_id: String,
    #[serde(default)]
    pub target_kind: JobTargetKind,
    pub target_name: Option<String>,
    pub branch_name: Option<String>,
    pub action_type: String,
    pub approved_at: DateTime<Utc>,
}

impl JobApprovalCommand {
    pub fn target_name(&self) -> &str {
        self.target_name.as_deref().unwrap_or("unspecified")
    }
}

#[cfg(test)]
mod tests {
    use super::{
        DeviceRegistrationTrustProof, JobDispatchMessage, JobTargetKind, OrchestratorTrustSigner,
        RegistrationChallengeResponse, RegistrationTrustIntent,
    };
    use chrono::Utc;

    #[test]
    fn registration_challenge_accepts_optional_metadata() {
        let payload = serde_json::json!({
            "challenge_id": "challenge-1",
            "challenge": "nonce",
            "issued_at": Utc::now(),
            "orchestrator_public_key": "public-key",
            "signature": "signature"
        });

        let challenge: RegistrationChallengeResponse =
            serde_json::from_value(payload).expect("challenge should deserialize");

        assert_eq!(challenge.orchestrator_key_id, None);
        assert!(challenge.trusted_signers.is_empty());
    }

    #[test]
    fn trust_proof_round_trips_extended_fields() {
        let proof = DeviceRegistrationTrustProof {
            trusted_orchestrator_public_keys: vec!["key-a".to_string()],
            trusted_orchestrator_key_ids: Some(vec!["current".to_string(), "next".to_string()]),
            orchestrator_key_id: "current".to_string(),
            orchestrator_challenge_id: "challenge-1".to_string(),
            orchestrator_challenge: "nonce".to_string(),
            orchestrator_challenge_issued_at: Utc::now(),
            orchestrator_public_key: "public-key".to_string(),
            orchestrator_signature: "signature".to_string(),
            edge_public_key: "edge-public".to_string(),
            edge_signature: "edge-signature".to_string(),
            registration_intent: RegistrationTrustIntent::Rotate,
            previous_edge_public_key: Some("previous-public".to_string()),
            previous_edge_signature: Some("previous-signature".to_string()),
            reenrollment_kind: Some("replace_existing_device_key".to_string()),
        };

        let json = serde_json::to_value(&proof).expect("proof should serialize");
        let decoded: DeviceRegistrationTrustProof =
            serde_json::from_value(json).expect("proof should deserialize");

        assert_eq!(decoded, proof);
    }

    #[test]
    fn registration_challenge_preserves_signer_list() {
        let challenge = RegistrationChallengeResponse {
            challenge_id: "challenge-1".to_string(),
            challenge: "nonce".to_string(),
            issued_at: Utc::now(),
            orchestrator_key_id: Some("orchestrator-1".to_string()),
            orchestrator_public_key: "public-key".to_string(),
            trusted_signers: vec![OrchestratorTrustSigner {
                key_id: "orchestrator-1".to_string(),
                public_key: "public-key".to_string(),
                active: true,
            }],
            signature: "signature".to_string(),
        };

        let json = serde_json::to_value(&challenge).expect("challenge should serialize");
        assert_eq!(json["trusted_signers"].as_array().map(Vec::len), Some(1));
    }

    #[test]
    fn repository_dispatch_defaults_target_kind_for_older_payloads() {
        let payload = serde_json::json!({
            "job_id": "job-1",
            "short_id": "job1",
            "correlation_id": "corr-1",
            "thread_id": "thread-1",
            "title": "Review repo",
            "device_id": "device-1",
            "target_name": "elowen-api",
            "base_branch": "main",
            "branch_name": "codex/job-1-review-repo",
            "request_text": "Review the repo",
            "execution_intent": "read_only",
            "dispatched_at": Utc::now()
        });

        let decoded: JobDispatchMessage =
            serde_json::from_value(payload).expect("dispatch should deserialize");

        assert_eq!(decoded.target_kind, JobTargetKind::Repository);
        assert_eq!(decoded.target_name(), "elowen-api");
        assert_eq!(decoded.prompt, "Review the repo");
    }
}
