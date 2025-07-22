# syntax = docker/dockerfile:1

# Ruby 3.3.0 이미지 사용
FROM ruby:3.3.0-slim as base

# Rails 앱은 /rails에서 실행
WORKDIR /rails

# 프로덕션 환경 설정
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# 빌드 단계
FROM base as build

# 빌드에 필요한 패키지 설치
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libxml2-dev \
    libxslt-dev \
    pkg-config \
    nodejs \
    npm \
    curl

# Gemfile 복사 및 gem 설치
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.7.0 && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Node 의존성 설치
COPY package.json package-lock.json ./
RUN npm ci || true

# 애플리케이션 코드 복사
COPY . .

# Vite 빌드 및 assets precompile (실패해도 계속)
RUN npm run build || true && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile || true

# 최종 이미지
FROM base

# 런타임에 필요한 패키지만 설치
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libpq-dev \
    libxml2 \
    libxslt1.1 && \
    rm -rf /var/lib/apt/lists/*

# 빌드 단계에서 필요한 파일들 복사
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# 비root 사용자 생성
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER rails:rails

# Entrypoint 설정
ENTRYPOINT ["./bin/docker-entrypoint"]

# 포트 설정
EXPOSE 3000

# 서버 시작 (포트는 환경 변수로 처리)
CMD ["sh", "-c", "bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}"]