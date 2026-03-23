---
alwaysApply: true
---

# 보안 규칙

## 시크릿 관리
- 환경 변수: `.env.local` (절대 커밋하지 않음)
- API 키/비밀번호를 코드, 설정 파일, 커밋 메시지에 하드코딩 금지
- 시크릿은 Secret Manager 또는 환경 변수로만 참조

## 입력 검증
- 사용자 입력: Zod로 반드시 검증
- SQL Injection: Prisma ORM으로 방지
- XSS: React 기본 이스케이프 + DOMPurify (HTML 렌더링 시)

## 접근 제어
- API 키: 서버 사이드에서만 접근
- 인증/인가 확인 필수
- 최소 권한 원칙 적용
