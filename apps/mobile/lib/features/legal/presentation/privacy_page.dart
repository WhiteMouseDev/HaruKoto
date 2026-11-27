import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/theme/haru_typography.dart';
import '../../../shared/widgets/business_info_footer.dart';
import 'legal_page_scaffold.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, this.onBack, this.onTabSelected});

  final VoidCallback? onBack;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final subText = light ? const Color(0xFF505050) : colors.onSurfaceVariant;
    final heading = HaruTypography.krRegularButton.copyWith(
      color: light ? Colors.black : colors.onSurface,
    );
    final mutedStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      letterSpacing: -0.3,
      color: subText,
    );
    final tint = light ? AppColors.redesignSurface : colors.surfaceContainerLow;

    return LegalPageScaffold(
      title: '개인정보처리방침',
      onBack: onBack,
      onTabSelected: onTabSelected,
      bodyLineHeight: 1.5,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  '시행일: 2025년 1월 1일',
                  style: mutedStyle,
                ),
                const SizedBox(height: AppSizes.lg),
                const Text(
                  '화이트마우스데브(이하 "회사")는 「개인정보 보호법」에 따라 이용자의 개인정보를 보호하고, '
                  '이와 관련한 고충을 신속하고 원활하게 처리할 수 있도록 다음과 같이 개인정보처리방침을 수립·공개합니다.',
                ),
                _sectionTitle(heading, '제1조 (수집하는 개인정보 항목)'),
                const Text('회사는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다.'),
                const SizedBox(height: AppSizes.sm),
                _infoCard(tint, [
                  _collectionGroup('1. 회원가입 시 필수 수집 항목', [
                    '이메일 주소',
                    '비밀번호 (암호화 저장)',
                    '닉네임',
                  ]),
                  _collectionGroup('2. 소셜 로그인 시 수집 항목', [
                    '소셜 계정 식별자 (ID)',
                    '이메일 주소',
                    '프로필 이미지 (선택)',
                  ]),
                  _collectionGroup('3. 서비스 이용 과정에서 자동 수집되는 항목', [
                    'JLPT 레벨 선택 정보',
                    '학습 진도 및 퀴즈 결과',
                    'AI 회화 대화 내용',
                    '학습 통계 (연속 학습일, XP, 레벨 등)',
                    '접속 로그, IP 주소, 브라우저 정보, 기기 정보',
                  ]),
                ]),
                _sectionTitle(heading, '제2조 (개인정보의 수집 및 이용 목적)'),
                _table(colors, tint, [
                  '수집 목적',
                  '수집 항목'
                ], [
                  ['회원 식별 및 가입 관리', '이메일, 비밀번호, 닉네임'],
                  ['학습 서비스 제공', 'JLPT 레벨, 학습 진도, 퀴즈 결과'],
                  ['AI 회화 서비스 제공', '대화 내용'],
                  ['서비스 개선 및 통계 분석', '접속 로그, 기기 정보, 학습 통계'],
                  ['고객 문의 대응', '이메일'],
                ]),
                _sectionTitle(heading, '제3조 (개인정보의 보유 및 이용 기간)'),
                _numberedList([
                  '회원의 개인정보는 서비스 이용 기간 동안 보유하며, 회원 탈퇴 요청 시 30일간 보관 후 지체 없이 파기합니다.',
                  '단, 관련 법령에서 정한 기간 동안 보관합니다:\n'
                      '  - 계약 또는 청약철회 등에 관한 기록: 5년\n'
                      '  - 대금결제 및 재화 등의 공급에 관한 기록: 5년\n'
                      '  - 소비자의 불만 또는 분쟁처리에 관한 기록: 3년\n'
                      '  - 접속에 관한 기록: 3개월',
                ]),
                _sectionTitle(heading, '제4조 (개인정보의 제3자 제공)'),
                const Text(
                    '회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 서비스 운영을 위해 다음과 같이 개인정보 처리를 위탁하고 있습니다.'),
                const SizedBox(height: AppSizes.sm),
                _table(colors, tint, [
                  '수탁업체',
                  '위탁 업무',
                  '제공 정보'
                ], [
                  ['Supabase Inc.', '데이터베이스 호스팅 및 인증 처리', '회원 정보, 학습 데이터'],
                  ['OpenAI / Google', 'AI 회화 서비스 제공', '대화 내용 (비식별 처리)'],
                  ['Vercel Inc.', '웹 서비스 호스팅', '접속 로그, IP 주소'],
                ]),
                _sectionTitle(heading, '제5조 (이용자의 권리 및 행사 방법)'),
                _numberedList([
                  '이용자는 언제든지 자신의 개인정보를 조회하거나 수정할 수 있습니다.',
                  '이용자는 회원 탈퇴를 통해 개인정보의 수집 및 이용에 대한 동의를 철회할 수 있습니다.',
                  '만 14세 미만 아동의 경우, 법정대리인이 아동의 개인정보에 대한 열람, 수정, 삭제, 처리 정지를 요구할 수 있습니다.',
                  '개인정보 관련 요청은 서비스 내 설정 또는 이메일 (whitemousedev@whitemouse.dev)을 통해 처리됩니다.',
                ]),
                _sectionTitle(heading, '제6조 (아동의 개인정보 보호)'),
                _numberedList([
                  '회사는 만 14세 미만 아동의 회원가입 시 법정대리인의 동의를 받습니다.',
                  '법정대리인은 아동의 개인정보 열람, 수정, 삭제, 처리 정지를 요청할 수 있으며, 이 경우 회사는 지체 없이 조치합니다.',
                ]),
                _sectionTitle(heading, '제7조 (개인정보의 파기)'),
                _numberedList([
                  '회사는 개인정보 보유 기간의 경과, 처리 목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체 없이 해당 개인정보를 파기합니다.',
                  '전자적 파일 형태의 정보는 기록을 재생할 수 없는 기술적 방법을 사용하여 삭제합니다.',
                ]),
                _sectionTitle(heading, '제8조 (개인정보의 안전성 확보 조치)'),
                const Text('회사는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:'),
                const SizedBox(height: AppSizes.sm),
                _infoCard(tint, [
                  _bulletList([
                    '비밀번호의 암호화 저장 및 전송',
                    'SSL/TLS를 통한 데이터 전송 암호화',
                    '개인정보 접근 권한 제한',
                    '정기적인 보안 점검',
                  ])
                ]),
                _sectionTitle(heading, '제9조 (개인정보 보호책임자)'),
                _infoCard(tint, [
                  _bulletList([
                    '성명: 김건우',
                    '직위: 대표',
                    '이메일: whitemousedev@whitemouse.dev',
                  ])
                ]),
                const SizedBox(height: AppSizes.sm),
                Text(
                  '개인정보 관련 문의, 불만 처리, 피해 구제 등에 관한 사항은 위 개인정보 보호책임자에게 문의하실 수 있습니다.',
                  style: mutedStyle,
                ),
                _sectionTitle(heading, '제10조 (권익침해 구제방법)'),
                const Text('이용자는 아래 기관에 개인정보 침해에 대한 피해 구제, 상담 등을 문의하실 수 있습니다.'),
                _bulletList([
                  '개인정보침해신고센터 (한국인터넷진흥원): (국번없이) 118',
                  '개인정보분쟁조정위원회: (국번없이) 1833-6972',
                  '대검찰청 사이버수사과: (국번없이) 1301',
                  '경찰청 사이버안전국: (국번없이) 182',
                ]),
                _sectionTitle(heading, '부칙'),
                const Text('본 개인정보처리방침은 2025년 1월 1일부터 시행합니다.'),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: BusinessInfoFooter(titleWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(TextStyle style, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Semantics(header: true, child: Text(title, style: style)),
    );
  }

  static Widget _collectionGroup(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: _bulletList(items),
        ),
      ],
    );
  }

  static Widget _infoCard(Color tint, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: children,
      ),
    );
  }

  static Widget _numberedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final (index, item) in items.indexed)
          _listRow('${index + 1}.', 16, item),
      ],
    );
  }

  static Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        for (final item in items) _listRow('-', 10, item),
      ],
    );
  }

  static Widget _listRow(String marker, double markerWidth, String item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: markerWidth),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Text(marker),
          ),
        ),
        Expanded(child: Text(item)),
      ],
    );
  }

  static Widget _table(
    ColorScheme colors,
    Color tint,
    List<String> headers,
    List<List<String>> rows,
  ) {
    final light = colors.brightness == Brightness.light;
    final grid = light ? AppColors.redesignControl : colors.outlineVariant;
    final headerDivider = light ? AppColors.redesignOutline : grid;
    const cellPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    const cellStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      letterSpacing: -0.3,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: grid),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(inside: BorderSide(color: grid)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: tint),
            children: [
              for (final (index, header) in headers.indexed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: index == headers.length - 1
                        ? null
                        : BorderDirectional(
                            end: BorderSide(color: headerDivider)),
                  ),
                  child: Padding(
                    padding: cellPadding,
                    child: Text(
                      header,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (final cell in row)
                  Padding(
                    padding: cellPadding,
                    child: Text(cell, style: cellStyle),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
