'use client';

import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function PrivacyPage() {
  const router = useRouter();

  return (
    <div className="bg-background min-h-dvh">
      <header className="border-border/50 sticky top-0 z-10 border-b bg-background/80 backdrop-blur-sm">
        <div className="mx-auto flex max-w-4xl items-center gap-2 px-4 py-3">
          <Button
            variant="ghost"
            size="icon"
            className="size-8"
            onClick={() => router.back()}
          >
            <ArrowLeft className="size-4" />
          </Button>
          <h1 className="text-base font-semibold">개인정보처리방침</h1>
        </div>
      </header>

      <main className="mx-auto max-w-4xl px-6 py-8">
        <p className="text-muted-foreground text-sm">
          시행일: 2025년 1월 1일
        </p>

        <div className="text-foreground/90 mt-8 space-y-8 text-sm leading-relaxed">
          <section>
            <p>
              화이트마우스데브(이하 &quot;회사&quot;)는 「개인정보 보호법」에
              따라 이용자의 개인정보를 보호하고, 이와 관련한 고충을 신속하고
              원활하게 처리할 수 있도록 다음과 같이 개인정보처리방침을
              수립·공개합니다.
            </p>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제1조 (수집하는 개인정보 항목)
            </h2>
            <p className="mt-2">
              회사는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다.
            </p>

            <div className="mt-3 space-y-3">
              <div className="bg-secondary/30 rounded-lg p-4">
                <h3 className="text-foreground text-xs font-semibold">
                  1. 회원가입 시 필수 수집 항목
                </h3>
                <ul className="mt-1.5 ml-4 list-disc space-y-0.5">
                  <li>이메일 주소</li>
                  <li>비밀번호 (암호화 저장)</li>
                  <li>닉네임</li>
                </ul>
              </div>

              <div className="bg-secondary/30 rounded-lg p-4">
                <h3 className="text-foreground text-xs font-semibold">
                  2. 소셜 로그인 시 수집 항목
                </h3>
                <ul className="mt-1.5 ml-4 list-disc space-y-0.5">
                  <li>소셜 계정 식별자 (ID)</li>
                  <li>이메일 주소</li>
                  <li>프로필 이미지 (선택)</li>
                </ul>
              </div>

              <div className="bg-secondary/30 rounded-lg p-4">
                <h3 className="text-foreground text-xs font-semibold">
                  3. 서비스 이용 과정에서 자동 수집되는 항목
                </h3>
                <ul className="mt-1.5 ml-4 list-disc space-y-0.5">
                  <li>JLPT 레벨 선택 정보</li>
                  <li>학습 진도 및 퀴즈 결과</li>
                  <li>AI 회화 대화 내용</li>
                  <li>학습 통계 (연속 학습일, XP, 레벨 등)</li>
                  <li>접속 로그, IP 주소, 브라우저 정보, 기기 정보</li>
                </ul>
              </div>
            </div>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제2조 (개인정보의 수집 및 이용 목적)
            </h2>
            <div className="mt-3 overflow-x-auto">
              <table className="border-border w-full border-collapse text-xs">
                <thead>
                  <tr className="bg-secondary/30">
                    <th className="border-border border px-3 py-2 text-left font-semibold">
                      수집 목적
                    </th>
                    <th className="border-border border px-3 py-2 text-left font-semibold">
                      수집 항목
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      회원 식별 및 가입 관리
                    </td>
                    <td className="border-border border px-3 py-2">
                      이메일, 비밀번호, 닉네임
                    </td>
                  </tr>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      학습 서비스 제공
                    </td>
                    <td className="border-border border px-3 py-2">
                      JLPT 레벨, 학습 진도, 퀴즈 결과
                    </td>
                  </tr>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      AI 회화 서비스 제공
                    </td>
                    <td className="border-border border px-3 py-2">
                      대화 내용
                    </td>
                  </tr>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      서비스 개선 및 통계 분석
                    </td>
                    <td className="border-border border px-3 py-2">
                      접속 로그, 기기 정보, 학습 통계
                    </td>
                  </tr>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      고객 문의 대응
                    </td>
                    <td className="border-border border px-3 py-2">이메일</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제3조 (개인정보의 보유 및 이용 기간)
            </h2>
            <ol className="mt-2 list-inside list-decimal space-y-1.5">
              <li>
                회원의 개인정보는 서비스 이용 기간 동안 보유하며, 회원 탈퇴
                요청 시 <strong>30일간 보관 후 지체 없이 파기</strong>합니다.
              </li>
              <li>
                단, 다음의 경우 해당 법령에서 정한 기간 동안 보관합니다:
                <ul className="mt-1 ml-4 list-disc space-y-0.5">
                  <li>
                    계약 또는 청약철회 등에 관한 기록: 5년 (전자상거래 등에서의
                    소비자보호에 관한 법률)
                  </li>
                  <li>대금결제 및 재화 등의 공급에 관한 기록: 5년</li>
                  <li>소비자의 불만 또는 분쟁처리에 관한 기록: 3년</li>
                  <li>접속에 관한 기록: 3개월 (통신비밀보호법)</li>
                </ul>
              </li>
            </ol>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제4조 (개인정보의 제3자 제공)
            </h2>
            <p className="mt-2">
              회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.
              다만, 서비스 운영을 위해 다음과 같이 개인정보 처리를 위탁하고
              있습니다.
            </p>

            <div className="mt-3 overflow-x-auto">
              <table className="border-border w-full border-collapse text-xs">
                <thead>
                  <tr className="bg-secondary/30">
                    <th className="border-border border px-3 py-2 text-left font-semibold">
                      수탁업체
                    </th>
                    <th className="border-border border px-3 py-2 text-left font-semibold">
                      위탁 업무
                    </th>
                    <th className="border-border border px-3 py-2 text-left font-semibold">
                      제공 정보
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      Supabase Inc.
                    </td>
                    <td className="border-border border px-3 py-2">
                      데이터베이스 호스팅 및 인증 처리
                    </td>
                    <td className="border-border border px-3 py-2">
                      회원 정보, 학습 데이터
                    </td>
                  </tr>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      OpenAI / Google
                    </td>
                    <td className="border-border border px-3 py-2">
                      AI 회화 서비스 제공
                    </td>
                    <td className="border-border border px-3 py-2">
                      대화 내용 (비식별 처리)
                    </td>
                  </tr>
                  <tr>
                    <td className="border-border border px-3 py-2">
                      Vercel Inc.
                    </td>
                    <td className="border-border border px-3 py-2">
                      웹 서비스 호스팅
                    </td>
                    <td className="border-border border px-3 py-2">
                      접속 로그, IP 주소
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제5조 (이용자의 권리 및 행사 방법)
            </h2>
            <ol className="mt-2 list-inside list-decimal space-y-1.5">
              <li>
                이용자는 언제든지 자신의 개인정보를 조회하거나 수정할 수
                있습니다.
              </li>
              <li>
                이용자는 회원 탈퇴를 통해 개인정보의 수집 및 이용에 대한 동의를
                철회할 수 있습니다.
              </li>
              <li>
                만 14세 미만 아동의 경우, 법정대리인이 아동의 개인정보에 대한
                열람, 수정, 삭제, 처리 정지를 요구할 수 있습니다.
              </li>
              <li>
                개인정보 관련 요청은 서비스 내 설정 또는 이메일
                (whitemousedev@whitemouse.dev)을 통해 처리됩니다.
              </li>
            </ol>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제6조 (아동의 개인정보 보호)
            </h2>
            <ol className="mt-2 list-inside list-decimal space-y-1.5">
              <li>
                회사는 만 14세 미만 아동의 회원가입 시 법정대리인의 동의를
                받습니다.
              </li>
              <li>
                법정대리인은 아동의 개인정보 열람, 수정, 삭제, 처리 정지를
                요청할 수 있으며, 이 경우 회사는 지체 없이 조치합니다.
              </li>
            </ol>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제7조 (개인정보의 파기)
            </h2>
            <ol className="mt-2 list-inside list-decimal space-y-1.5">
              <li>
                회사는 개인정보 보유 기간의 경과, 처리 목적 달성 등 개인정보가
                불필요하게 되었을 때에는 지체 없이 해당 개인정보를 파기합니다.
              </li>
              <li>
                전자적 파일 형태의 정보는 기록을 재생할 수 없는 기술적 방법을
                사용하여 삭제합니다.
              </li>
            </ol>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제8조 (개인정보의 안전성 확보 조치)
            </h2>
            <p className="mt-2">
              회사는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고
              있습니다:
            </p>
            <ul className="mt-1.5 ml-4 list-disc space-y-1">
              <li>비밀번호의 암호화 저장 및 전송</li>
              <li>SSL/TLS를 통한 데이터 전송 암호화</li>
              <li>개인정보 접근 권한 제한</li>
              <li>정기적인 보안 점검</li>
            </ul>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제9조 (개인정보 보호책임자)
            </h2>
            <div className="bg-secondary/30 mt-2 rounded-lg p-4">
              <ul className="space-y-1">
                <li>
                  <strong>성명:</strong> 김건우
                </li>
                <li>
                  <strong>직위:</strong> 대표
                </li>
                <li>
                  <strong>이메일:</strong> whitemousedev@whitemouse.dev
                </li>
              </ul>
            </div>
            <p className="text-muted-foreground mt-2 text-xs">
              개인정보 관련 문의, 불만 처리, 피해 구제 등에 관한 사항은 위
              개인정보 보호책임자에게 문의하실 수 있습니다.
            </p>
          </section>

          <section>
            <h2 className="text-foreground font-bold">
              제10조 (권익침해 구제방법)
            </h2>
            <p className="mt-2">
              이용자는 아래 기관에 개인정보 침해에 대한 피해 구제, 상담 등을
              문의하실 수 있습니다.
            </p>
            <ul className="mt-2 ml-4 list-disc space-y-1">
              <li>개인정보침해신고센터 (한국인터넷진흥원): (국번없이) 118</li>
              <li>개인정보분쟁조정위원회: (국번없이) 1833-6972</li>
              <li>대검찰청 사이버수사과: (국번없이) 1301</li>
              <li>경찰청 사이버안전국: (국번없이) 182</li>
            </ul>
          </section>

          <section className="border-border/50 rounded-xl border p-4">
            <h2 className="text-foreground font-bold">부칙</h2>
            <p className="mt-2">
              본 개인정보처리방침은 2025년 1월 1일부터 시행합니다.
            </p>
          </section>
        </div>
      </main>
    </div>
  );
}
