String scenarioDifficultyLabel(String difficulty) => switch (difficulty) {
      'BEGINNER' => '초급',
      'INTERMEDIATE' => '중급',
      'ADVANCED' => '고급',
      _ => difficulty,
    };
