'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

type HeatmapRecord = {
  date: string;
  wordsStudied: number;
};

type HeatmapProps = {
  records: HeatmapRecord[];
  year: number;
  onYearChange: (year: number) => void;
};

const MONTH_LABELS = [
  '1월',
  '2월',
  '3월',
  '4월',
  '5월',
  '6월',
  '7월',
  '8월',
  '9월',
  '10월',
  '11월',
  '12월',
];

const DAY_LABELS = ['월', '', '수', '', '금', '', ''];

function getIntensity(count: number, max: number): number {
  if (count === 0) return 0;
  if (max === 0) return 0;
  const ratio = count / max;
  if (ratio <= 0.25) return 1;
  if (ratio <= 0.5) return 2;
  if (ratio <= 0.75) return 3;
  return 4;
}

const INTENSITY_COLORS = [
  'bg-secondary', // 0 - no activity
  'bg-[#FCE7EC]', // 1 - light pink
  'bg-[#F6A5B3]', // 2 - cherry pink
  'bg-[#F494A4]', // 3 - medium pink
  'bg-[#E5607A]', // 4 - deep pink
];

const DARK_INTENSITY_COLORS = [
  'dark:bg-muted', // 0
  'dark:bg-[#3D1F2A]', // 1
  'dark:bg-[#6B3040]', // 2
  'dark:bg-[#994158]', // 3
  'dark:bg-[#CC5570]', // 4
];

type DayCell = {
  date: string;
  count: number;
  weekIndex: number;
  dayIndex: number;
};

function buildYearGrid(year: number, records: HeatmapRecord[]) {
  const recordMap = new Map(records.map((r) => [r.date, r.wordsStudied]));

  const startDate = new Date(Date.UTC(year, 0, 1));
  const endDate = new Date(Date.UTC(year, 11, 31));

  // Adjust start to previous Monday
  const startDay = startDate.getUTCDay();
  const mondayOffset = startDay === 0 ? -6 : 1 - startDay;
  const gridStart = new Date(startDate);
  gridStart.setUTCDate(gridStart.getUTCDate() + mondayOffset);

  const cells: DayCell[] = [];
  const current = new Date(gridStart);
  let weekIndex = 0;

  while (current <= endDate || current.getUTCDay() !== 1) {
    const dayIndex = (current.getUTCDay() + 6) % 7; // Mon=0
    const dateStr = current.toISOString().split('T')[0];
    const isInYear =
      current.getUTCFullYear() === year ||
      (current < startDate && dayIndex < 7);

    if (isInYear || current <= endDate) {
      cells.push({
        date: dateStr,
        count: recordMap.get(dateStr) ?? 0,
        weekIndex,
        dayIndex,
      });
    }

    current.setUTCDate(current.getUTCDate() + 1);
    if (current.getUTCDay() === 1) weekIndex++;

    // Safety: don't go too far past end of year
    if (weekIndex > 53) break;
  }

  return cells;
}

function getMonthPositions(year: number): { label: string; weekIndex: number }[] {
  const positions: { label: string; weekIndex: number }[] = [];
  const startDate = new Date(Date.UTC(year, 0, 1));
  const startDay = startDate.getUTCDay();
  const mondayOffset = startDay === 0 ? -6 : 1 - startDay;
  const gridStart = new Date(startDate);
  gridStart.setUTCDate(gridStart.getUTCDate() + mondayOffset);

  for (let m = 0; m < 12; m++) {
    const firstOfMonth = new Date(Date.UTC(year, m, 1));
    const diff = Math.floor(
      (firstOfMonth.getTime() - gridStart.getTime()) / (1000 * 60 * 60 * 24)
    );
    const weekIndex = Math.floor(diff / 7);
    positions.push({ label: MONTH_LABELS[m], weekIndex });
  }

  return positions;
}

export function Heatmap({ records, year, onYearChange }: HeatmapProps) {
  const [hoveredCell, setHoveredCell] = useState<DayCell | null>(null);

  const cells = useMemo(() => buildYearGrid(year, records), [year, records]);
  const monthPositions = useMemo(() => getMonthPositions(year), [year]);

  const maxCount = useMemo(
    () => Math.max(...cells.map((c) => c.count), 1),
    [cells]
  );

  const totalWeeks = useMemo(() => {
    if (cells.length === 0) return 0;
    return Math.max(...cells.map((c) => c.weekIndex)) + 1;
  }, [cells]);

  const totalStudied = useMemo(
    () => cells.reduce((sum, c) => sum + c.count, 0),
    [cells]
  );

  const activeDays = useMemo(
    () => cells.filter((c) => c.count > 0).length,
    [cells]
  );

  const currentYear = new Date().getFullYear();

  return (
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">연간 학습 히트맵</h3>
          <div className="flex items-center gap-1">
            <button
              onClick={() => onYearChange(year - 1)}
              className="text-muted-foreground hover:text-foreground rounded p-1 transition-colors"
              aria-label="이전 년도"
            >
              <ChevronLeft className="size-4" />
            </button>
            <span className="min-w-[3rem] text-center text-sm font-medium">
              {year}
            </span>
            <button
              onClick={() => onYearChange(year + 1)}
              disabled={year >= currentYear}
              className="text-muted-foreground hover:text-foreground rounded p-1 transition-colors disabled:opacity-30"
              aria-label="다음 년도"
            >
              <ChevronRight className="size-4" />
            </button>
          </div>
        </div>

        {/* Heatmap grid */}
        <div className="overflow-x-auto">
          <div className="min-w-[640px]">
            {/* Month labels */}
            <div className="mb-1 flex" style={{ paddingLeft: 28 }}>
              {monthPositions.map((mp, i) => {
                const nextWeek =
                  i < 11 ? monthPositions[i + 1].weekIndex : totalWeeks;
                const span = nextWeek - mp.weekIndex;
                return (
                  <span
                    key={mp.label}
                    className="text-muted-foreground text-[10px]"
                    style={{
                      width: `${(span / totalWeeks) * 100}%`,
                      minWidth: 0,
                    }}
                  >
                    {span >= 3 ? mp.label : ''}
                  </span>
                );
              })}
            </div>

            {/* Grid with day labels */}
            <div className="flex gap-1">
              {/* Day labels */}
              <div className="flex flex-col gap-[3px]" style={{ width: 20 }}>
                {DAY_LABELS.map((label, i) => (
                  <span
                    key={i}
                    className="text-muted-foreground flex items-center text-[10px]"
                    style={{ height: 11 }}
                  >
                    {label}
                  </span>
                ))}
              </div>

              {/* Cells */}
              <div className="flex flex-1 gap-[3px]">
                {Array.from({ length: totalWeeks }, (_, wi) => (
                  <div key={wi} className="flex flex-col gap-[3px]">
                    {Array.from({ length: 7 }, (_, di) => {
                      const cell = cells.find(
                        (c) => c.weekIndex === wi && c.dayIndex === di
                      );
                      if (!cell) {
                        return (
                          <div
                            key={di}
                            className="rounded-sm"
                            style={{ width: 11, height: 11 }}
                          />
                        );
                      }
                      const intensity = getIntensity(cell.count, maxCount);
                      return (
                        <motion.div
                          key={di}
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          transition={{
                            delay: wi * 0.005,
                            duration: 0.2,
                          }}
                          className={`rounded-sm ${INTENSITY_COLORS[intensity]} ${DARK_INTENSITY_COLORS[intensity]} cursor-pointer transition-transform hover:scale-125`}
                          style={{ width: 11, height: 11 }}
                          onMouseEnter={() => setHoveredCell(cell)}
                          onMouseLeave={() => setHoveredCell(null)}
                        />
                      );
                    })}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Tooltip */}
        {hoveredCell && (
          <div className="text-muted-foreground text-center text-xs">
            {hoveredCell.date} · {hoveredCell.count}개 학습
          </div>
        )}

        {/* Legend + Summary */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1">
            <span className="text-muted-foreground text-[10px]">Less</span>
            {INTENSITY_COLORS.map((color, i) => (
              <div
                key={i}
                className={`rounded-sm ${color} ${DARK_INTENSITY_COLORS[i]}`}
                style={{ width: 11, height: 11 }}
              />
            ))}
            <span className="text-muted-foreground text-[10px]">More</span>
          </div>
          <div className="text-muted-foreground text-xs">
            총 {totalStudied}개 · {activeDays}일 학습
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
