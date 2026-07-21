import prisma from "./prisma.service";

export class WorkoutService {
  /**
   * Start a new gym workout session
   */
  static async startWorkoutSession(userId: string, name: string, exercises?: any[]) {
    if (exercises && exercises.length > 0) {
      for (const ex of exercises) {
        if (!ex.id) {
          let dbEx = await prisma.exercise.findFirst({ where: { name: ex.name } });
          if (!dbEx) {
            dbEx = await prisma.exercise.create({
              data: {
                name: ex.name,
                muscleGroup: ex.muscleGroup || 'Other',
              }
            });
          }
          ex.id = dbEx.id;
        }
      }
    }

    // Determine the data to create
    return prisma.workoutSession.create({
      data: {
        userId,
        name,
        ...(exercises && exercises.length > 0 && {
          exercises: {
            create: exercises.map((ex, index) => ({
              // if ex.id exists, it's the Exercise template DB id
              exerciseId: ex.id,
              order: index,
            }))
          }
        })
      },
      include: {
        exercises: true,
      }
    });
  }

  /**
   * Add an exercise to an ongoing session
   */
  static async addExerciseToSession(sessionId: string, exerciseId: string, order: number, notes?: string) {
    return prisma.workoutExercise.create({
      data: {
        sessionId,
        exerciseId,
        order,
        notes,
      },
    });
  }

  /**
   * Log a single set (weight, reps, rpe)
   */
  static async logSet(workoutExerciseId: string, setNumber: number, reps?: number, weightKg?: number, rpe?: number) {
    const existing = await prisma.exerciseSet.findFirst({
      where: { workoutExerciseId, setNumber }
    });

    if (existing) {
      return prisma.exerciseSet.update({
        where: { id: existing.id },
        data: {
          reps,
          weightKg,
          rpe,
          isCompleted: true,
        },
      });
    }

    return prisma.exerciseSet.create({
      data: {
        workoutExerciseId,
        setNumber,
        reps,
        weightKg,
        rpe,
        isCompleted: true,
      },
    });
  }

  /**
   * Finish the workout session
   */
  static async finishSession(sessionId: string, notes?: string) {
    return prisma.workoutSession.update({
      where: { id: sessionId },
      data: {
        endedAt: new Date(),
        notes,
      },
    });
  }
}
