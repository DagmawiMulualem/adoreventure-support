import SwiftUI

struct TravelTriviaGame: View {
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var timeRemaining = 30
    @State private var gameTimer: Timer?
    @State private var isGameActive = false
    @State private var showResult = false
    @State private var selectedAnswer: Int? = nil
    @State private var isCorrect = false
    
    // Travel trivia questions
    private let triviaQuestions = [
        TriviaQuestion(
            question: "Which city is known as the 'City of Light'?",
            options: ["Paris", "London", "Rome", "Amsterdam"],
            correctAnswer: 0,
            explanation: "Paris is called the 'City of Light' due to its early adoption of street lighting."
        ),
        TriviaQuestion(
            question: "What is the largest desert in the world?",
            options: ["Sahara", "Antarctic", "Arabian", "Gobi"],
            correctAnswer: 1,
            explanation: "The Antarctic Desert is the largest desert, covering about 14.2 million square kilometers."
        ),
        TriviaQuestion(
            question: "Which country has the most UNESCO World Heritage Sites?",
            options: ["Italy", "China", "Spain", "France"],
            correctAnswer: 0,
            explanation: "Italy leads with 58 UNESCO World Heritage Sites."
        ),
        TriviaQuestion(
            question: "What is the capital of Australia?",
            options: ["Sydney", "Melbourne", "Canberra", "Brisbane"],
            correctAnswer: 2,
            explanation: "Canberra is the capital, while Sydney is the largest city."
        ),
        TriviaQuestion(
            question: "Which mountain range runs through South America?",
            options: ["Himalayas", "Rocky Mountains", "Andes", "Alps"],
            correctAnswer: 2,
            explanation: "The Andes is the longest continental mountain range in the world."
        ),
        TriviaQuestion(
            question: "What is the largest ocean on Earth?",
            options: ["Atlantic", "Indian", "Arctic", "Pacific"],
            correctAnswer: 3,
            explanation: "The Pacific Ocean covers about 63 million square miles, making it the largest ocean."
        ),
        TriviaQuestion(
            question: "Which city is home to the ancient Colosseum?",
            options: ["Athens", "Rome", "Florence", "Venice"],
            correctAnswer: 1,
            explanation: "The Colosseum, built in 70-80 AD, is located in Rome, Italy."
        ),
        TriviaQuestion(
            question: "What is the smallest country in the world?",
            options: ["Monaco", "San Marino", "Vatican City", "Liechtenstein"],
            correctAnswer: 2,
            explanation: "Vatican City is the world's smallest country, covering just 0.17 square miles."
        ),
        TriviaQuestion(
            question: "Which river is the longest in the world?",
            options: ["Amazon", "Nile", "Yangtze", "Mississippi"],
            correctAnswer: 1,
            explanation: "The Nile River is approximately 4,135 miles long, making it the world's longest river."
        ),
        TriviaQuestion(
            question: "What is the capital of Japan?",
            options: ["Kyoto", "Osaka", "Tokyo", "Yokohama"],
            correctAnswer: 2,
            explanation: "Tokyo has been Japan's capital since 1868 and is the world's most populous metropolitan area."
        ),
        TriviaQuestion(
            question: "Which country is known as the Land of Fire and Ice?",
            options: ["Norway", "Finland", "Iceland", "Sweden"],
            correctAnswer: 2,
            explanation: "Iceland is called the Land of Fire and Ice due to its volcanoes and glaciers."
        ),
        TriviaQuestion(
            question: "What is the largest island in the world?",
            options: ["Australia", "Greenland", "Borneo", "Madagascar"],
            correctAnswer: 1,
            explanation: "Greenland is the world's largest island, covering about 836,330 square miles."
        ),
        TriviaQuestion(
            question: "Which city is known as the Big Apple?",
            options: ["Los Angeles", "Chicago", "New York", "Boston"],
            correctAnswer: 2,
            explanation: "New York City is nicknamed the Big Apple, a term popularized in the 1920s."
        ),
        TriviaQuestion(
            question: "What is the capital of Brazil?",
            options: ["Rio de Janeiro", "São Paulo", "Brasília", "Salvador"],
            correctAnswer: 2,
            explanation: "Brasília became Brazil's capital in 1960, replacing Rio de Janeiro."
        ),
        TriviaQuestion(
            question: "Which country has the most time zones?",
            options: ["Russia", "United States", "France", "Australia"],
            correctAnswer: 2,
            explanation: "France has 12 time zones due to its overseas territories around the world."
        ),
        TriviaQuestion(
            question: "What is the highest mountain in Africa?",
            options: ["Mount Kenya", "Mount Kilimanjaro", "Mount Elgon", "Mount Meru"],
            correctAnswer: 1,
            explanation: "Mount Kilimanjaro in Tanzania is Africa's highest peak at 19,341 feet."
        ),
        TriviaQuestion(
            question: "Which city is known as the Eternal City?",
            options: ["Athens", "Rome", "Jerusalem", "Istanbul"],
            correctAnswer: 1,
            explanation: "Rome is called the Eternal City due to its ancient history and lasting influence."
        ),
        TriviaQuestion(
            question: "What is the largest rainforest in the world?",
            options: ["Congo", "Amazon", "Borneo", "Daintree"],
            correctAnswer: 1,
            explanation: "The Amazon Rainforest covers about 2.1 million square miles across South America."
        ),
        TriviaQuestion(
            question: "Which country is home to the Great Wall?",
            options: ["Japan", "Korea", "China", "Mongolia"],
            correctAnswer: 2,
            explanation: "The Great Wall of China stretches over 13,000 miles and was built over centuries."
        ),
        TriviaQuestion(
            question: "What is the capital of South Africa?",
            options: ["Johannesburg", "Cape Town", "Pretoria", "All three"],
            correctAnswer: 3,
            explanation: "South Africa has three capitals: Pretoria (executive), Cape Town (legislative), and Bloemfontein (judicial)."
        ),
        TriviaQuestion(
            question: "Which sea is the saltiest in the world?",
            options: ["Dead Sea", "Red Sea", "Mediterranean", "Black Sea"],
            correctAnswer: 0,
            explanation: "The Dead Sea has a salinity of about 34%, making it the saltiest body of water on Earth."
        )
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Game header
            VStack(spacing: 4) {
                Text("🌍 Travel Trivia")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Test your travel knowledge!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Score and timer
            HStack {
                Label("Score: \(score)", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                
                Spacer()
                
                Label("Time: \(timeRemaining)s", systemImage: "clock.fill")
                    .foregroundStyle(timeRemaining < 10 ? .red : .blue)
                    .scaleEffect(timeRemaining < 10 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: timeRemaining)
            }
            .font(.caption)
            .fontWeight(.medium)
            
            // Question counter
            Text("Question \(currentQuestionIndex + 1) of \(triviaQuestions.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
            
            // Question area
            VStack(spacing: 12) {
                // Question text
                Text(triviaQuestions[currentQuestionIndex].question)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                    )
                
                // Answer options
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        AnswerButton(
                            index: index,
                            text: triviaQuestions[currentQuestionIndex].options[index],
                            isSelected: selectedAnswer == index,
                            isCorrect: isCorrect,
                            onTap: { selectAnswer(index) }
                        )
                    }
                }
                
                // Explanation (shown after answer)
                if selectedAnswer != nil {
                    ExplanationView(explanation: triviaQuestions[currentQuestionIndex].explanation)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    resetGame()
                } label: {
                    Label("New Game", systemImage: "arrow.clockwise.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if selectedAnswer != nil {
                    Button {
                        nextQuestion()
                    } label: {
                        Label("Next", systemImage: "arrow.right.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            // Game over message
            if showResult {
                Text("🎉 Game Complete! Final Score: \(score)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            startGame()
        }
        .onDisappear {
            stopGame()
        }
    }
    
    // MARK: - Game Logic
    
    private func startGame() {
        isGameActive = true
        resetGame()
        startTimer()
    }
    
    private func stopGame() {
        isGameActive = false
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    private func startTimer() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                gameOver()
            }
        }
    }
    
    private func selectAnswer(_ answerIndex: Int) {
        selectedAnswer = answerIndex
        isCorrect = answerIndex == triviaQuestions[currentQuestionIndex].correctAnswer
        
        if isCorrect {
            score += 10
        }
        
        // Auto-advance after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if selectedAnswer != nil {
                nextQuestion()
            }
        }
    }
    
    private func nextQuestion() {
        selectedAnswer = nil
        isCorrect = false
        
        if currentQuestionIndex < triviaQuestions.count - 1 {
            currentQuestionIndex += 1
        } else {
            gameOver()
        }
    }
    
    private func resetGame() {
        currentQuestionIndex = 0
        score = 0
        timeRemaining = 30
        selectedAnswer = nil
        isCorrect = false
        showResult = false
    }
    
    private func gameOver() {
        stopGame()
        showResult = true
    }
}

// MARK: - Supporting Views

struct AnswerButton: View {
    let index: Int
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let onTap: () -> Void
    
    private var backgroundColor: Color {
        if !isSelected { return Color(.systemGray6) }
        return isCorrect ? .green.opacity(0.2) : .red.opacity(0.2)
    }
    
    private var borderColor: Color {
        if !isSelected { return .clear }
        return isCorrect ? .green.opacity(0.5) : .red.opacity(0.5)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("\(["A", "B", "C", "D"][index]).")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? .green : .red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isSelected)
    }
}

struct ExplanationView: View {
    let explanation: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text("💡 Explanation")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            
            Text(explanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
        )
    }
}

// MARK: - Data Models

struct TriviaQuestion {
    let question: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String
}

#Preview {
    TravelTriviaGame()
        .padding()
        .background(Color(.systemGroupedBackground))
}
