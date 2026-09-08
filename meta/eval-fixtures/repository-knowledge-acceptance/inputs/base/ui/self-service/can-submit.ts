export interface SelfServiceSubmissionState {
  verificationComplete: boolean;
}

export function canSubmitSelfService(state: SelfServiceSubmissionState): boolean {
  return state.verificationComplete;
}

