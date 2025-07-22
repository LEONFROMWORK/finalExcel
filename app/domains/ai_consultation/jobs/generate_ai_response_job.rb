# frozen_string_literal: true

module AiConsultation
  module Jobs
    class GenerateAiResponseJob < ApplicationJob
      queue_as :ai_responses

      def perform(chat_session_id, user_message_id)
        @chat_session = ChatSession.find(chat_session_id)
        @user_message = ChatMessage.find(user_message_id)
        @user = @chat_session.user

        # 통합 AI 서비스 사용
        ai_service = UnifiedAiService.new(@user)
        
        # AI 응답 생성
        result = ai_service.process_chat_message(@chat_session, @user_message.content)
        
        if result[:success]
          # 성공 시 이미 메시지가 생성됨
          Rails.logger.info "AI response generated successfully using #{result[:result][:model_used]}"
          
          # 코드 실행이 필요한 경우 별도 처리
          if result[:result][:code_snippets]&.any?
            process_code_suggestions(@chat_session, result[:result][:code_snippets])
          end
        else
          # 오류 처리
          @chat_session.add_assistant_message(
            "죄송합니다. AI 응답 생성 중 오류가 발생했습니다: #{result[:errors]&.join(', ') || result[:error]}",
            {
              error: true,
              errors: result[:errors] || [result[:error]]
            }
          )
        end

        # Update session activity
        @chat_session.touch
      rescue StandardError => e
        Rails.logger.error "AI response generation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        # Create error message for user
        @chat_session.add_assistant_message(
          "시스템 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
          {
            error: e.message,
            error_type: e.class.name
          }
        )
      end

      private

      def generate_response
        # Get context from recent messages
        context = build_conversation_context

        # If user uploaded an image, analyze it
        if @user_message.has_image?
          analyze_image_with_context(context)
        else
          generate_text_response(context)
        end
      end

      def build_conversation_context
        recent_messages = @chat_session.messages
                                      .recent
                                      .limit(10)
                                      .reverse
                                      .map { |m| format_message_for_context(m) }

        recent_messages.join("\n")
      end

      def format_message_for_context(message)
        role = message.assistant? ? "Assistant" : "User"
        content = message.content

        if message.has_image?
          content += " [이미지 첨부됨]"
        end

        "#{role}: #{content}"
      end

      def analyze_image_with_context(context)
        # This would integrate with an AI service that can analyze images
        # For now, return a placeholder response

        if @user_message.content.present?
          base_prompt = @user_message.content
        else
          base_prompt = "이 Excel 스크린샷을 분석해주세요."
        end

        # In production, this would call OpenAI's vision API or similar
        mock_analysis = <<~RESPONSE
          업로드하신 이미지를 분석했습니다.

          [이미지 분석 결과]
          - Excel 스프레드시트가 포함된 것으로 보입니다
          - 데이터 구조와 수식을 확인했습니다

          구체적인 질문이나 도움이 필요한 부분이 있으시면 말씀해주세요.
        RESPONSE

        mock_analysis
      end

      def generate_text_response(context)
        user_query = @user_message.content

        # Search knowledge base for relevant Q&A pairs
        relevant_knowledge = search_knowledge_base(user_query)

        # Build prompt with context and knowledge
        prompt = build_ai_prompt(user_query, context, relevant_knowledge)

        # In production, this would call OpenAI API
        # For now, return a contextual mock response
        generate_mock_response(user_query, relevant_knowledge)
      end

      def search_knowledge_base(query)
        # Use the KnowledgeBase SearchService to find relevant Q&A pairs
        result = ::KnowledgeBase::Services::SearchService.call(
          query: query,
          limit: 3,
          threshold: 0.7
        )

        return [] unless result.success?

        result.data[:results].map do |qa_pair|
          {
            question: qa_pair.question,
            answer: qa_pair.answer,
            relevance: qa_pair.relevance_score
          }
        end
      rescue StandardError => e
        Rails.logger.error "Knowledge base search failed: #{e.message}"
        []
      end

      def build_ai_prompt(query, context, knowledge)
        prompt = <<~PROMPT
          You are an Excel expert assistant helping users with Excel-related questions and problems.

          Recent conversation context:
          #{context}

          Relevant knowledge from database:
          #{format_knowledge_for_prompt(knowledge)}

          User question: #{query}

          Please provide a helpful, accurate response in Korean. Focus on practical solutions and clear explanations.
        PROMPT

        prompt
      end

      def format_knowledge_for_prompt(knowledge)
        return "No specific knowledge found." if knowledge.empty?

        knowledge.map do |item|
          "Q: #{item[:question]}\nA: #{item[:answer]}\n"
        end.join("\n")
      end

      def generate_mock_response(query, knowledge)
        # This is a mock response generator for development
        # In production, this would be replaced with actual AI API calls

        if knowledge.any?
          # Use knowledge base answer as base
          base_answer = knowledge.first[:answer]

          <<~RESPONSE
            #{base_answer}

            추가로 도움이 필요하신 부분이 있으시면 구체적으로 말씀해주세요!
          RESPONSE
        elsif query.downcase.include?("sum") || query.include?("합계")
          <<~RESPONSE
            Excel에서 합계를 구하는 방법을 설명드리겠습니다.

            1. **SUM 함수 사용하기**
               - 기본 문법: `=SUM(범위)`
               - 예시: `=SUM(A1:A10)` - A1부터 A10까지의 합계

            2. **자동 합계 기능**
               - 데이터 범위 선택 후 Alt + = 단축키
               - 또는 홈 탭의 Σ(시그마) 버튼 클릭

            3. **조건부 합계**
               - SUMIF: `=SUMIF(범위, 조건, 합계범위)`
               - SUMIFS: 여러 조건 적용 가능

            구체적인 상황을 알려주시면 더 정확한 도움을 드릴 수 있습니다!
          RESPONSE
        elsif query.downcase.include?("vlookup") || query.include?("찾기")
          <<~RESPONSE
            VLOOKUP 함수 사용법을 안내해드립니다.

            **기본 문법**
            `=VLOOKUP(찾을값, 테이블범위, 열번호, [일치옵션])`

            **매개변수 설명**
            - 찾을값: 검색할 값
            - 테이블범위: 데이터가 있는 전체 범위
            - 열번호: 반환할 값이 있는 열 번호
            - 일치옵션: FALSE(정확히 일치) 또는 TRUE(근사치)

            **예시**
            `=VLOOKUP(A2, B2:D10, 3, FALSE)`

            더 나은 대안으로 XLOOKUP 함수도 고려해보세요!
          RESPONSE
        else
          <<~RESPONSE
            Excel 관련 질문 주셔서 감사합니다.

            "#{query}"에 대해 구체적으로 어떤 도움이 필요하신가요?

            예를 들어:
            - 특정 함수의 사용법
            - 데이터 분석 방법
            - 차트 생성
            - 오류 해결

            등을 알려주시면 더 정확한 답변을 드릴 수 있습니다.
          RESPONSE
        end
      end

      def calculate_tokens(content)
        # Simple token estimation (actual implementation would use tiktoken or similar)
        content.split.size * 1.3
      end
      
      def process_code_suggestions(chat_session, code_snippets)
        # 코드 제안이 있을 때 처리
        code_snippets.each do |snippet|
          # 코드 실행 가능 여부 확인
          if snippet[:language] == 'python' && snippet[:code].present?
            # 향후 Jupyter 커널 통합 시 실행
            Rails.logger.info "Code suggestion available for execution: #{snippet[:purpose]}"
          end
        end
      end
    end
  end
end
