# frozen_string_literal: true

module Api
  module V1
    module AiConsultation
      class ErrorSolutionsController < Api::V1::ApiController
        # FREE TEST PERIOD - Authentication disabled
        # before_action :authenticate_user!
        before_action :set_excel_file
        
        # POST /api/v1/ai_consultation/error_solutions/analyze
        def analyze
          # Smart Error Solver 사용 (Tier 방식)
          solver = SmartExcelErrorSolver.new(@excel_file, error_context_params)
          result = solver.call
          
          if result.success?
            render json: {
              success: true,
              solution: result.data[:solution],
              type: result.data[:type],
              tier: result.data[:tier],
              cost: result.data[:cost],
              confidence: result.data[:confidence],
              requires_escalation: result.data[:requires_escalation]
            }
          else
            render json: {
              success: false,
              error: result.error,
              attempted_solutions: result.data[:attempted_solutions]
            }, status: :unprocessable_entity
          end
        end
        
        # POST /api/v1/ai_consultation/error_solutions/execute_advanced
        def execute_advanced
          # Enterprise tier 사용자만 접근 가능
          unless current_user.ai_tier == 'enterprise'
            return render json: {
              error: 'This feature requires Enterprise tier'
            }, status: :forbidden
          end
          
          # Code Interpreter 실행 (향후 구현)
          render json: {
            message: 'Code execution feature coming soon',
            tier: 'enterprise',
            available_features: {
              data_transformation: true,
              formula_generation: true,
              analysis_automation: true,
              visualization: true
            }
          }
        end
        
        # GET /api/v1/ai_consultation/error_solutions/static_analysis
        def static_analysis
          analyzer = ExcelStaticAnalyzer.new(@excel_file)
          
          render json: {
            errors: analyzer.detect_errors,
            formula_analysis: analyzer.analyze_formulas,
            data_quality: analyzer.check_data_quality
          }
        end
        
        # POST /api/v1/ai_consultation/error_solutions/quick_fix
        def quick_fix
          error_type = params[:error_type]
          location = params[:location]
          
          # 간단한 자동 수정 시도
          quick_fixer = QuickErrorFixer.new(@excel_file)
          result = quick_fixer.fix_error(error_type, location)
          
          if result[:success]
            render json: {
              success: true,
              fixed: true,
              original: result[:original],
              fixed_value: result[:fixed_value],
              message: result[:message]
            }
          else
            render json: {
              success: false,
              message: result[:message],
              manual_steps: result[:manual_steps]
            }
          end
        end
        
        private
        
        def set_excel_file
          @excel_file = current_user.excel_files.find(params[:excel_file_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Excel file not found' }, status: :not_found
        end
        
        def error_context_params
          params.permit(:problem_description, :selected_errors, :focus_area).to_h
        end
      end
    end
  end
end