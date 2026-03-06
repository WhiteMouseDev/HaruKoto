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
  '1월', '2월', '3월', '4월', '5월', '6월',
  '7월', '8월', '9월', '10월', '11월', '12월',
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

function getGridStart(year: number): Date {
  const startDate = new Date(Date.UTC(year, 0, 1));
  const startDay = startDate.getUTCDay();
  const mondayOffset = startDay === 0 ? -6 : 1 - startDay;
  const gridStart = new Date(startDate);
  gridStart.setUTCDate(gridStart.getUTCDate() + mondayOffset);
  return gridStart;
}

function buildYearGrid(year: number, records: HeatmapRecord[]) {
  const recordMap = new Map(records.map((r) => [r.date, r.wordsStudied]));

  const endDate = new Date(Date.UTC(year, 11, 31));
  const gridStart = getGridStart(year);

  const cells: DayCell[] = [];
  const current = new Date(gridStart);
  let weekIndex = 0;

  while (current <= endDate) {
    const dayIndex = (current.getUTCDay() + 6) % 7; // Mon=0
    const dateStr = current.toISOString().split('T')[0];

    cells.push({
      date: dateStr,
      count: recordMap.get(dateStr) ?? 0,
      weekIndex,
      dayIndex,
    });

    current.setUTCDate(current.getUTCDate() + 1);
    if (current.getUTCDay() === 1) weekIndex++;

    if (weekIndex > 53) break;
  }

  return cells;
}

function getMonthPositions(year: number, totalWeeks: number): { label: string; weekIndex: number; span: number }[] {
  const gridStart = getGridStart(year);
  const positions: { label: string; weekIndex: number; span: number }[] = [];

  for (let m = 0; m < 12; m++) {
    const firstOfMonth = new Date(Date.UTC(year, m, 1));
    const diff = Math.floor(
      (firstOfMonth.getTime() - gridStart.getTime()) / (1000 * 60 * 60 * 24)
    );
    const weekIndex = Math.floor(diff / 7);
    positions.push({ label: MONTH_LABELS[m], weekIndex, span: 0 });
  }

  // Calculate spans
  for (let i = 0; i < 12; i++) {
    const nextWeek = i < 11 ? positions[i + 1].weekIndex : totalWeeks;
    positions[i].span = nextWeek - positions[i].weekIndex;
  }

  return positions;
}

export function Heatmap({ records, year, onYearChange }: HeatmapProps) {
  const [hoveredCell, setHoveredCell] = useState<DayCell | null>(null);

  const cells = useMemo(() => buildYearGrid(year, records), [year, records]);

  const maxCount = useMemo(
    () => Math.max(...cells.map((c) => c.count), 1),
    [cells]
  );

  const totalWeeks = useMemo(() => {
    if (cells.length === 0) return 0;
    return Math.max(...cells.map((c) => c.weekIndex)) + 1;
  }, [cells]);

  const monthPositions = useMemo(
    () => getMonthPositions(year, totalWeeks),
    [year, totalWeeks]
  );

  const totalStudied = useMemo(
    () => cells.reduce((sum, c) => sum + c.count, 0),
    [cells]
  );

  const activeDays = useMemo(
    () => cells.filter((c) => c.count > 0).length,
    [cells]
  );

  const currentYear = new Date().getFullYear();

  // Build week columns for rendering
  const weekColumns = useMemo(() => {
    const columns: (DayCell | null)[][] = [];
    for (let wi = 0; wi < totalWeeks; wi++) {
      const column: (DayCell | null)[] = [];
      for (let di = 0; di < 7; di++) {
        const cell = cells.find((c) => c.weekIndex === wi && c.dayIndex === di);
        column.push(cell ?? null);
      }
      columns.push(column);
    }
    return columns;
  }, [cells, totalWeeks]);

  const DAY_LABEL_WIDTH = 20;
  const CELL_SIZE = 11;
  const GAP = 3;
  const gridWidth = totalWeeks * CELL_SIZE + (totalWeeks - 1) * GAP;

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
          <div style={{ width: gridWidth + DAY_LABEL_WIDTH + 4, minWidth: 640 }}>
            {/* Month labels — same grid as cells */}
            <div
              className="mb-1"
              style={{
                display: 'grid',
                gridTemplateColumns: `${DAY_LABEL_WIDTH + 4}px repeat(${totalWeeks}, ${CELL_SIZE}px)`,
                gap: `0 ${GAP}px`,
              }}
            >
              {/* Day label spacer */}
              <div />
              {monthPositions.map((mp) => {
                if (mp.span < 3) return null;
                return (
                  <span
                    key={mp.label}
                    className="text-muted-foreground text-[10px]"
                    style={{
                      gridColumn: `${mp.weekIndex + 2} / span ${Math.min(mp.span, totalWeeks - mp.weekIndex)}`,
                    }}
                  >
                    {mp.label}
                  </span>
                );
              })}
            </div>

            {/* Grid with day labels */}
            <div className="flex" style={{ gap: 4 }}>
              {/* Day labels */}
              <div className="flex flex-col" style={{ width: DAY_LABEL_WIDTH, gap: GAP }}>
                {DAY_LABELS.map((label, i) => (
                  <span
                    key={i}
                    className="text-muted-foreground flex items-center text-[10px]"
                    style={{ height: CELL_SIZE }}
                  >
                    {label}
                  </span>
                ))}
              </div>

              {/* Cells */}
              <div className="flex" style={{ gap: GAP }}>
                {weekColumns.map((column, wi) => (
                  <div key={wi} className="flex flex-col" style={{ gap: GAP }}>
                    {column.map((cell, di) => {
                      if (!cell) {
                        return (
                          <div
                            key={di}
                            className="rounded-sm"
                            style={{ width: CELL_SIZE, height: CELL_SIZE }}
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
                          style={{ width: CELL_SIZE, height: CELL_SIZE }}
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

        {/* Tooltip — fixed height to prevent layout shift */}
        <div className="text-muted-foreground h-5 text-center text-xs">
          {hoveredCell
            ? `${hoveredCell.date} · ${hoveredCell.count}개 학습`
            : '\u00A0'}
        </div>

        {/* Legend + Summary */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1">
            <span className="text-muted-foreground text-[10px]">Less</span>
            {INTENSITY_COLORS.map((color, i) => (
              <div
                key={i}
                className={`rounded-sm ${color} ${DARK_INTENSITY_COLORS[i]}`}
                style={{ width: CELL_SIZE, height: CELL_SIZE }}
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
