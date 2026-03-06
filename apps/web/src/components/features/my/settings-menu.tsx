'use client';

import type { CallSettingsData } from './call-settings';
import { StudySettingsSection } from './study-settings-section';
import { AppSettingsSection } from './app-settings-section';
import { InfoSection } from './info-section';
import { AccountSection } from './account-section';

type SettingsMenuProps = {
  jlptLevel: string;
  dailyGoal: number;
  showKana: boolean;
  onUpdate: (field: string, value: unknown) => Promise<void>;
  callSettings: CallSettingsData;
  onCallSettingsUpdate: (settings: Partial<CallSettingsData>) => void;
  onLogout: () => void;
  loggingOut: boolean;
  onDeleteAccount: () => void;
  deleting: boolean;
};

export function SettingsMenu({
  jlptLevel,
  dailyGoal,
  showKana,
  onUpdate,
  callSettings,
  onCallSettingsUpdate,
  onLogout,
  loggingOut,
  onDeleteAccount,
  deleting,
}: SettingsMenuProps) {
  return (
    <div className="flex flex-col gap-3">
      <StudySettingsSection
        jlptLevel={jlptLevel}
        dailyGoal={dailyGoal}
        showKana={showKana}
        onUpdate={onUpdate}
      />

      <AppSettingsSection
        jlptLevel={jlptLevel}
        callSettings={callSettings}
        onCallSettingsUpdate={onCallSettingsUpdate}
      />

      <InfoSection />

      <AccountSection
        onLogout={onLogout}
        loggingOut={loggingOut}
        onDeleteAccount={onDeleteAccount}
        deleting={deleting}
      />

      {/* Version */}
      <div className="flex justify-center pb-2">
        <span className="text-muted-foreground text-xs">v0.1.0</span>
      </div>
    </div>
  );
}
