export const QUIZ_REFRESH_REQUIRED =
  '안전한 답안 저장을 위해 새로고침 후 저장된 퀴즈를 이어 풀어 주세요.';
export const QUIZ_ATTEMPT_CONFLICT =
  '이미 사용된 답안 요청이에요. 저장된 퀴즈를 다시 열어 주세요.';
export const QUIZ_ALREADY_COMPLETED =
  '이미 완료된 퀴즈예요. 저장된 결과를 확인해 주세요.';
export const QUIZ_STATE_CHANGED =
  '다른 화면에서 이미 답안이 저장됐어요. 저장된 퀴즈를 다시 열어 주세요.';
export const QUIZ_TYPE_MISMATCH = '저장된 퀴즈의 문항 유형과 일치하지 않아요.';
export const QUIZ_ACK_MISMATCH =
  '답안 저장 확인이 일치하지 않아요. 저장된 퀴즈를 다시 열어 주세요.';
export const QUIZ_WRITE_CONFLICT =
  '답안을 안전하게 저장하지 못했어요. 저장된 퀴즈를 다시 열어 주세요.';
export const QUIZ_CONTENT_UNAVAILABLE =
  '문항의 학습 정보를 찾을 수 없어요. 저장된 기록은 유지됩니다.';

export function quizRequiresReload(error: Error): boolean {
  return [
    QUIZ_REFRESH_REQUIRED,
    QUIZ_ATTEMPT_CONFLICT,
    QUIZ_ALREADY_COMPLETED,
    QUIZ_STATE_CHANGED,
    QUIZ_TYPE_MISMATCH,
    QUIZ_ACK_MISMATCH,
    QUIZ_WRITE_CONFLICT,
    QUIZ_CONTENT_UNAVAILABLE,
  ].includes(error.message);
}
