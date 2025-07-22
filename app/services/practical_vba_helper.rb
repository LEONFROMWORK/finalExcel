# frozen_string_literal: true

# 실용적인 VBA 오류 해결 도우미
# 90%의 일반적인 VBA 오류에 대한 즉각적인 해결책 제공
class PracticalVbaHelper
  # 가장 자주 발생하는 VBA 오류 10개 정의
  INSTANT_SOLUTIONS = {
    # 오류 번호 기반 매칭
    "1004" => {
      message: "실행 시간 오류 '1004': 응용 프로그램 정의 또는 개체 정의 오류",
      solutions: [
        "시트가 보호되어 있다면: ActiveSheet.Unprotect",
        "범위가 잘못되었다면: Range(\"A1:B10\") 형식으로 정확히 지정",
        "파일이 읽기 전용이라면: 다른 이름으로 저장 후 재시도",
        "병합된 셀 접근 시: MergeArea 속성 사용"
      ],
      example_code: <<~VBA,
        ' 올바른 범위 지정 예시
        Dim ws As Worksheet
        Set ws = ThisWorkbook.Worksheets("Sheet1")
        ws.Range("A1:B10").Value = "데이터"
        
        ' 보호 해제 예시
        If ws.ProtectContents Then
          ws.Unprotect Password:="yourpassword"
        End If
      VBA
      confidence: 0.9
    },
    
    "9" => {
      message: "실행 시간 오류 '9': 첨자가 범위를 벗어났습니다",
      solutions: [
        "시트명 확인: Worksheets(\"Sheet1\") - 정확한 이름과 공백 체크",
        "시트 존재 여부 확인 후 접근",
        "배열 크기 확인: UBound() 함수 사용",
        "컬렉션 인덱스는 1부터 시작함을 기억"
      ],
      example_code: <<~VBA,
        ' 안전한 시트 접근
        Dim ws As Worksheet
        On Error Resume Next
        Set ws = Worksheets("SheetName")
        On Error GoTo 0
        
        If Not ws Is Nothing Then
          ws.Activate
        Else
          MsgBox "시트를 찾을 수 없습니다"
        End If
      VBA
      confidence: 0.95
    },
    
    "13" => {
      message: "실행 시간 오류 '13': 형식이 일치하지 않습니다",
      solutions: [
        "변수 타입 확인: Dim x As Long (숫자), Dim s As String (문자)",
        "문자를 숫자로 변환: Val(문자열) 또는 CDbl(문자열)",
        "날짜 형식 변환: CDate() 또는 DateValue()",
        "IsNumeric() 함수로 숫자 여부 확인 후 처리"
      ],
      example_code: <<~VBA,
        ' 타입 안전한 변환
        Dim userInput As String
        Dim numValue As Double
        
        userInput = InputBox("숫자를 입력하세요")
        
        If IsNumeric(userInput) Then
          numValue = CDbl(userInput)
        Else
          MsgBox "올바른 숫자가 아닙니다"
        End If
      VBA
      confidence: 0.9
    },
    
    "424" => {
      message: "실행 시간 오류 '424': 개체가 필요합니다",
      solutions: [
        "Set 키워드 추가: Set obj = CreateObject(\"Excel.Application\")",
        "개체 변수 선언: Dim ws As Worksheet",
        "Nothing 체크: If Not obj Is Nothing Then",
        "개체가 제대로 초기화되었는지 확인"
      ],
      example_code: <<~VBA,
        ' 올바른 개체 할당
        Dim ws As Worksheet
        Dim rng As Range
        
        ' Set 키워드 필수
        Set ws = ActiveSheet
        Set rng = ws.Range("A1:B10")
        
        ' 사용 전 Nothing 체크
        If Not rng Is Nothing Then
          rng.Value = "데이터"
        End If
      VBA
      confidence: 0.85
    },
    
    "91" => {
      message: "실행 시간 오류 '91': 개체 변수 또는 With 블록 변수가 설정되지 않았습니다",
      solutions: [
        "변수 초기화 확인: Set 키워드로 개체 할당",
        "Find 메서드 결과 확인: 찾지 못하면 Nothing 반환",
        "With 블록 내 올바른 개체 참조",
        "개체 생성 실패 가능성 확인"
      ],
      example_code: <<~VBA,
        ' Find 메서드 안전 사용
        Dim foundCell As Range
        Set foundCell = Range("A1:A100").Find("검색어")
        
        If Not foundCell Is Nothing Then
          foundCell.Interior.Color = vbYellow
        Else
          MsgBox "검색어를 찾을 수 없습니다"
        End If
      VBA
      confidence: 0.85
    },
    
    "438" => {
      message: "실행 시간 오류 '438': 개체가 이 속성 또는 메서드를 지원하지 않습니다",
      solutions: [
        "개체의 정확한 속성/메서드명 확인",
        "IntelliSense 활용하여 사용 가능한 멤버 확인",
        "개체 타입이 올바른지 확인",
        "참조 라이브러리가 추가되었는지 확인"
      ],
      example_code: <<~VBA,
        ' 올바른 개체 사용 예시
        Dim ws As Worksheet
        Set ws = ActiveSheet
        
        ' Worksheet 개체의 올바른 속성
        ws.Name = "NewName"
        ws.Visible = xlSheetVisible
        
        ' 잘못된 예: ws.Text (존재하지 않는 속성)
      VBA
      confidence: 0.8
    },
    
    "6" => {
      message: "실행 시간 오류 '6': 오버플로",
      solutions: [
        "변수 타입 확대: Integer → Long, Long → Double",
        "계산 중간 결과도 오버플로 가능성 체크",
        "큰 숫자는 Double 또는 Currency 타입 사용",
        "나누기 전 0 체크"
      ],
      example_code: <<~VBA,
        ' 오버플로 방지
        Dim bigNumber As Long  ' Integer 대신 Long 사용
        Dim result As Double   ' 큰 계산 결과용
        
        bigNumber = 100000
        result = CDbl(bigNumber) * 1000  ' CDbl로 안전하게 변환
      VBA
      confidence: 0.85
    },
    
    "error 1004 copy" => {
      message: "복사/붙여넣기 관련 1004 오류",
      solutions: [
        "대상 범위와 원본 범위 크기가 동일한지 확인",
        "다른 통합 문서 간 복사 시 두 파일 모두 열려있는지 확인",
        "PasteSpecial 메서드 사용 고려",
        "클립보드 지우기: Application.CutCopyMode = False"
      ],
      example_code: <<~VBA,
        ' 안전한 복사/붙여넣기
        Dim sourceRange As Range
        Dim destRange As Range
        
        Set sourceRange = Sheet1.Range("A1:B10")
        Set destRange = Sheet2.Range("C1")
        
        sourceRange.Copy
        destRange.PasteSpecial xlPasteValues
        Application.CutCopyMode = False
      VBA
      confidence: 0.85
    },
    
    "compile error" => {
      message: "컴파일 오류",
      solutions: [
        "Option Explicit 추가하여 변수 선언 강제",
        "모든 변수가 선언되었는지 확인",
        "Sub/Function의 End Sub/End Function 확인",
        "VBA 편집기에서 디버그 → 컴파일 실행"
      ],
      example_code: <<~VBA,
        ' 올바른 코드 구조
        Option Explicit
        
        Sub MyProcedure()
          Dim i As Long
          Dim ws As Worksheet
          
          Set ws = ActiveSheet
          For i = 1 To 10
            ws.Cells(i, 1).Value = i
          Next i
        End Sub
      VBA
      confidence: 0.8
    },
    
    "byref argument type" => {
      message: "ByRef 인수 형식이 일치하지 않습니다",
      solutions: [
        "함수 매개변수와 전달 인수의 타입 일치",
        "ByVal로 변경 고려",
        "명시적 타입 변환: CLng(), CStr() 등",
        "Variant 타입 사용 고려"
      ],
      example_code: <<~VBA,
        ' 타입 일치 예시
        Sub Main()
          Dim num As Long
          num = 100
          Call ProcessNumber(num)  ' Long 타입 전달
        End Sub
        
        Sub ProcessNumber(ByVal value As Long)  ' ByVal 사용
          Debug.Print value * 2
        End Sub
      VBA
      confidence: 0.8
    }
  }.freeze
  
  # 성능 관련 키워드 패턴
  PERFORMANCE_KEYWORDS = {
    "slow" => {
      solutions: [
        "화면 업데이트 중지: Application.ScreenUpdating = False",
        "자동 계산 중지: Application.Calculation = xlCalculationManual",
        "이벤트 중지: Application.EnableEvents = False",
        "작업 완료 후 모두 다시 활성화"
      ],
      example_code: <<~VBA
        Sub OptimizedProcedure()
          Application.ScreenUpdating = False
          Application.Calculation = xlCalculationManual
          Application.EnableEvents = False
          
          ' 여기에 작업 코드
          
          Application.EnableEvents = True
          Application.Calculation = xlCalculationAutomatic
          Application.ScreenUpdating = True
        End Sub
      VBA
    },
    "select" => {
      solutions: [
        "Select/Activate 사용 피하기",
        "직접 개체 참조 사용",
        "With 문으로 반복 참조 줄이기"
      ],
      example_code: <<~VBA
        ' 나쁜 예
        Sheets("Sheet1").Select
        Range("A1").Select
        Selection.Value = 100
        
        ' 좋은 예
        Sheets("Sheet1").Range("A1").Value = 100
      VBA
    }
  }.freeze
  
  def solve(error_description)
    return { error: "오류 설명을 입력해주세요" } if error_description.blank?
    
    # 1단계: 즉시 해결 가능한지 확인
    instant_solution = find_instant_solution(error_description)
    return format_response(instant_solution, :exact_match) if instant_solution
    
    # 2단계: 성능 관련 키워드 매칭
    performance_solution = find_performance_solution(error_description)
    return format_response(performance_solution, :performance) if performance_solution
    
    # 3단계: 간단한 키워드 매칭
    keyword_solution = find_by_keywords(error_description)
    return format_response(keyword_solution, :keyword_match) if keyword_solution
    
    # 4단계: 기본 가이드 제공
    generic_guide(error_description)
  end
  
  def get_common_patterns
    # 자주 사용되는 패턴 반환 (UI에서 빠른 선택용)
    INSTANT_SOLUTIONS.map do |key, solution|
      {
        key: key,
        message: solution[:message],
        confidence: solution[:confidence]
      }
    end.sort_by { |p| -p[:confidence] }.take(5)
  end
  
  private
  
  def find_instant_solution(error)
    error_lower = error.downcase
    
    INSTANT_SOLUTIONS.each do |key, solution|
      # 오류 번호나 키워드가 포함되어 있는지 확인
      if error_lower.include?(key.downcase) || 
         (solution[:message] && error_lower.include?(solution[:message].downcase[0..20]))
        return solution
      end
    end
    
    nil
  end
  
  def find_performance_solution(error)
    error_lower = error.downcase
    
    PERFORMANCE_KEYWORDS.each do |keyword, solution|
      if error_lower.include?(keyword)
        return {
          message: "성능 최적화 관련",
          solutions: solution[:solutions],
          example_code: solution[:example_code],
          confidence: 0.75
        }
      end
    end
    
    nil
  end
  
  def find_by_keywords(error)
    error_lower = error.downcase
    
    # 추가 키워드 매칭
    case error_lower
    when /loop|for|while/
      {
        message: "반복문 관련 문제",
        solutions: [
          "For Each가 일반적으로 For i보다 빠름",
          "큰 범위는 배열로 읽어서 처리",
          "DoEvents로 중간에 응답성 유지",
          "Exit For로 조기 종료 조건 추가"
        ],
        confidence: 0.7
      }
    when /array|배열/
      {
        message: "배열 관련 문제",
        solutions: [
          "동적 배열: ReDim Preserve 사용",
          "배열 크기: UBound(arr) - LBound(arr) + 1",
          "2차원 배열: arr(행, 열) 순서",
          "Variant 배열로 범위 한번에 읽기"
        ],
        confidence: 0.7
      }
    when /pivot|피벗/
      {
        message: "피벗 테이블 관련",
        solutions: [
          "피벗 캐시 새로고침: PivotCache.Refresh",
          "데이터 범위 동적 지정",
          "피벗 필드 존재 확인 후 설정",
          "GetPivotData 함수 활용"
        ],
        confidence: 0.65
      }
    else
      nil
    end
  end
  
  def format_response(solution, match_type)
    {
      success: true,
      error_type: solution[:message],
      solutions: solution[:solutions],
      example_code: solution[:example_code],
      confidence: solution[:confidence],
      match_type: match_type,
      need_ai_help: solution[:confidence] < 0.7
    }
  end
  
  def generic_guide(error)
    {
      success: true,
      error_type: "일반 VBA 문제",
      solutions: [
        "Option Explicit 추가하여 변수 오류 방지",
        "On Error GoTo ErrorHandler로 오류 처리 추가",
        "Debug.Print로 변수값 확인",
        "F8키로 한 줄씩 실행하며 디버깅",
        "중단점(F9) 설정하여 문제 지점 파악"
      ],
      example_code: <<~VBA,
        Sub DebugExample()
          On Error GoTo ErrorHandler
          
          ' 디버깅용 출력
          Debug.Print "시작: " & Now
          
          ' 여기에 문제가 있는 코드
          
          Exit Sub
        ErrorHandler:
          MsgBox "오류 발생: " & Err.Description
        End Sub
      VBA
      confidence: 0.5,
      match_type: :generic,
      need_ai_help: true
    }
  end
end