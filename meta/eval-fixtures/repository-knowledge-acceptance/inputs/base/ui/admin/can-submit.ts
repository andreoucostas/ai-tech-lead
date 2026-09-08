export interface AdminSubmissionState {
  verificationComplete: boolean;
  hasPrivilegedBypass: boolean;
}

export function canSubmitAdmin(state: AdminSubmissionState): boolean {
  return state.verificationComplete || state.hasPrivilegedBypass;
}

