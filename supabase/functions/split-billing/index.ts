type ExpenseType = "Group Bill" | "Personal Expense";

type Participant = {
  id: string;
  name: string;
};

type SplitRequest = {
  totalAmount: number;
  expenseType: ExpenseType;
  participants: Participant[];
};

export function calculateSplit(request: SplitRequest) {
  const { totalAmount, expenseType, participants } = request;

  if (totalAmount <= 0) {
    throw new Error("Total amount must be greater than zero.");
  }

  if (participants.length === 0) {
    throw new Error("At least one participant is required.");
  }

  if (expenseType === "Personal Expense") {
    return {
      expenseType,
      totalAmount,
      splits: [
        {
          participantId: participants[0].id,
          participantName: participants[0].name,
          amount: Number(totalAmount.toFixed(2)),
        },
      ],
    };
  }

  const equalShare = Number(
    (totalAmount / participants.length).toFixed(2)
  );

  let remaining = Number(totalAmount.toFixed(2));

  const splits = participants.map((participant, index) => {
    const amount =
      index === participants.length - 1
        ? Number(remaining.toFixed(2))
        : equalShare;

    remaining -= amount;

    return {
      participantId: participant.id,
      participantName: participant.name,
      amount: Number(amount.toFixed(2)),
    };
  });

  return {
    expenseType,
    totalAmount: Number(totalAmount.toFixed(2)),
    splits,
  };
}