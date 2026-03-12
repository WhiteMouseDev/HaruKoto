import 'package:flutter/material.dart';
import '../../../core/constants/sizes.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(title: const Text('이용약관')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text(
            '시행일: 2025년 1월 1일',
            style: TextStyle(fontSize: 13, color: subTextColor),
          ),
          const SizedBox(height: AppSizes.lg),

          _sectionTitle(theme, '제1조 (목적)'),
          _paragraph(
            '본 약관은 화이트마우스데브(이하 "회사")가 제공하는 하루코토 서비스(이하 "서비스")의 '
            '이용 조건 및 절차, 회사와 이용자 간의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.',
          ),

          _sectionTitle(theme, '제2조 (용어의 정의)'),
          _numberedList([
            '"서비스"란 회사가 제공하는 일본어 학습 관련 웹·모바일 애플리케이션 및 관련 제반 서비스를 의미합니다.',
            '"이용자"란 본 약관에 동의하고 서비스를 이용하는 자를 의미합니다.',
            '"회원"이란 서비스에 회원가입을 하여 계정을 보유한 이용자를 의미합니다.',
            '"콘텐츠"란 서비스 내에서 제공되는 학습 자료, 퀴즈, AI 회화 데이터 등을 의미합니다.',
          ]),

          _sectionTitle(theme, '제3조 (약관의 효력 및 변경)'),
          _numberedList([
            '본 약관은 서비스 화면에 게시하거나 기타의 방법으로 이용자에게 공지함으로써 효력이 발생합니다.',
            '회사는 관련 법령에 위배되지 않는 범위에서 본 약관을 변경할 수 있으며, 변경 시 적용일자 및 변경 사유를 명시하여 최소 7일 전에 공지합니다.',
            '변경된 약관에 동의하지 않는 이용자는 서비스 이용을 중단하고 탈퇴할 수 있습니다.',
          ]),

          _sectionTitle(theme, '제4조 (회원가입 및 계정)'),
          _numberedList([
            '회원가입은 이용자가 약관에 동의하고 회사가 정한 양식에 따라 회원 정보를 기입한 후 신청하며, 회사가 이를 승낙함으로써 성립됩니다.',
            '만 14세 미만의 아동이 서비스에 가입하고자 하는 경우, 법정대리인(부모 등)의 동의가 필요합니다.',
            '회원은 가입 시 제공한 정보가 정확하고 최신임을 보장해야 하며, 변경 사항이 있을 경우 즉시 수정해야 합니다.',
            '회원은 자신의 계정 정보를 타인과 공유하거나 양도할 수 없으며, 계정의 관리 책임은 회원에게 있습니다.',
          ]),

          _sectionTitle(theme, '제5조 (서비스의 제공 및 변경)'),
          _numberedList([
            '회사는 다음과 같은 서비스를 제공합니다:\n'
                '  - JLPT(N5~N1) 단어·문법 학습 및 퀴즈\n'
                '  - AI 기반 일본어 회화 연습\n'
                '  - 학습 통계 및 진도 관리\n'
                '  - 게이미피케이션 기반 학습 동기 부여',
            '회사는 서비스의 내용을 변경하거나 중단할 수 있으며, 이 경우 사전에 공지합니다.',
            'AI 회화 기능은 외부 AI 서비스(OpenAI, Google 등)를 활용하며, 해당 서비스의 정책 변경에 따라 기능이 제한될 수 있습니다.',
          ]),

          _sectionTitle(theme, '제6조 (유료 서비스 및 결제)'),
          _numberedList([
            '회사는 무료 서비스 외에 유료 구독 서비스(이하 "프리미엄")를 제공하며, 이용자는 회사가 정한 요금을 결제하고 이용할 수 있습니다.',
            '프리미엄 서비스는 결제 완료 시점부터 즉시 제공되며, 구독 기간은 월간(결제일로부터 30일) 또는 연간(결제일로부터 365일)입니다.',
            '구독은 별도의 해지 요청이 없는 한, 구독 기간 만료 시 자동으로 갱신됩니다.',
          ]),

          _sectionTitle(theme, '제7조 (청약철회 및 환불)'),
          _numberedList([
            '이용자는 결제일로부터 7일 이내에 서비스를 이용하지 않은 경우 청약철회(전액 환불)를 요청할 수 있습니다.',
            '다만, 서비스 이용 이력이 있는 경우(퀴즈 풀기, AI 회화 등 유료 기능 사용) 또는 「전자상거래 등에서의 소비자보호에 관한 법률」 제17조 제2항에 해당하는 경우 청약철회가 제한됩니다.',
            '서비스 이용 이력이 있으나 결제일로부터 7일 이내인 경우, 이용일수를 차감한 잔여 금액을 환불합니다. (일할 계산)',
            '결제일로부터 7일 경과 후에는 환불이 불가하며, 구독 해지 시 잔여 구독 기간까지 서비스를 이용할 수 있습니다.',
            '환불 요청은 서비스 내 설정 또는 이메일 (whitemousedev@whitemouse.dev)을 통해 접수하며, 접수 후 영업일 기준 3일 이내에 처리됩니다.',
          ]),

          _sectionTitle(theme, '제8조 (구독 해지 및 취소)'),
          _numberedList([
            '이용자는 언제든지 서비스 내 "MY > 구독 관리" 메뉴에서 구독을 해지할 수 있습니다.',
            '구독 해지 시 즉시 서비스가 중단되지 않으며, 현재 결제한 구독 기간이 만료될 때까지 프리미엄 서비스를 이용할 수 있습니다.',
            '구독 기간 만료 후에는 무료 플랜으로 자동 전환되며, 학습 데이터는 유지됩니다.',
          ]),

          _sectionTitle(theme, '제9조 (교환 규정)'),
          _numberedList([
            '본 서비스는 디지털 콘텐츠 제공 서비스로, 물리적 상품의 배송이 수반되지 않으므로 교환은 적용되지 않습니다.',
            '구독 플랜 변경(월간 <-> 연간)을 원하는 경우, 현재 구독을 해지한 후 새로운 플랜으로 재구독할 수 있습니다.',
          ]),

          _sectionTitle(theme, '제10조 (이용자의 의무)'),
          _paragraph('이용자는 다음 행위를 해서는 안 됩니다:'),
          _numberedList([
            '타인의 정보를 도용하여 회원가입하는 행위',
            '서비스의 운영을 방해하거나 시스템에 부하를 주는 행위',
            '서비스 내 콘텐츠를 무단으로 복제·배포·상업적으로 이용하는 행위',
            'AI 회화 기능을 학습 목적 외로 악용하거나, 부적절한 콘텐츠를 생성하는 행위',
            '기타 관련 법령에 위반되는 행위',
          ]),

          _sectionTitle(theme, '제11조 (서비스 이용 제한)'),
          _numberedList([
            '회사는 이용자가 본 약관을 위반한 경우, 서비스 이용을 제한하거나 회원 자격을 정지·상실시킬 수 있습니다.',
            '회사는 서비스의 안정적 운영을 위해 일시적으로 이용을 제한할 수 있으며, 사전에 공지합니다.',
          ]),

          _sectionTitle(theme, '제12조 (지적재산권)'),
          _numberedList([
            '서비스 내 콘텐츠(학습 자료, 디자인, 소프트웨어 등)에 대한 지적재산권은 회사에 귀속됩니다.',
            '이용자가 서비스를 통해 생성한 학습 데이터(퀴즈 결과, AI 대화 기록 등)의 소유권은 이용자에게 있으나, 회사는 서비스 개선을 위해 비식별화된 형태로 활용할 수 있습니다.',
          ]),

          _sectionTitle(theme, '제13조 (면책 조항)'),
          _numberedList([
            '회사는 천재지변, 전쟁, 기간통신사업자의 서비스 중단 등 불가항력적 사유로 인한 서비스 중단에 대해 책임을 지지 않습니다.',
            'AI 회화 기능에서 제공되는 응답은 참고용이며, 회사는 AI 응답의 정확성이나 적절성을 보장하지 않습니다.',
            '이용자가 서비스 내에서 얻은 학습 결과에 대해 회사는 책임을 지지 않습니다.',
          ]),

          _sectionTitle(theme, '제14조 (회원 탈퇴 및 자격 상실)'),
          _numberedList([
            '회원은 언제든지 서비스 내에서 탈퇴를 요청할 수 있으며, 회사는 즉시 처리합니다.',
            '탈퇴 시 회원의 개인정보는 30일간 보관 후 파기됩니다. 단, 관련 법령에 따라 보관이 필요한 정보는 해당 기간 동안 보관됩니다.',
          ]),

          _sectionTitle(theme, '제15조 (분쟁 해결)'),
          _numberedList([
            '서비스 이용과 관련하여 분쟁이 발생한 경우, 회사와 이용자는 상호 협의하여 해결하도록 노력합니다.',
            '협의가 이루어지지 않는 경우, 회사 소재지를 관할하는 법원을 관할 법원으로 합니다.',
          ]),

          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('부칙',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSizes.sm),
                const Text('본 약관은 2025년 1월 1일부터 시행합니다.',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }

  static Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.lg, bottom: AppSizes.sm),
      child: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget _paragraph(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, height: 1.6));
  }

  static Widget _numberedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text('${entry.key + 1}.',
                    style: const TextStyle(fontSize: 13)),
              ),
              Expanded(
                child: Text(entry.value,
                    style: const TextStyle(fontSize: 13, height: 1.6)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
