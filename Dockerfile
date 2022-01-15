# Definir imagem a ser utilizada para aplicação has backend
FROM ruby:2.7.2-alpine as pre-builder
# Instalar dependências necessárias  e remover cache de instalação
RUN apk add --update --no-cache \
    openssl \
    tar \
    build-base \
    tzdata \
    postgresql-dev \
    postgresql-client \
    nodejs \
  && wget https://yarnpkg.com/latest.tar.gz \
  && mkdir -p /opt/yarn \
  && tar -xf latest.tar.gz -C /opt/yarn --strip 1 \
  && mkdir -p /app 
# exportar PATH com binário do yarn
ENV PATH="$PATH:/opt/yarn/bin" 
#Definir variáveis utilizada pela aplicação.
ENV RAILS_ENV='production'
ENV RACK_ENV='production'
ENV SECRET_KEY_BASE=dummy
ENV RAILS_ROOT  /app
ENV PORT=5000
# Definir diretório de trabalho padrão da imagem.
WORKDIR $RAILS_ROOT
# Copiar arquivos Gemfile e Gemfile.lock antes para ativar uso de cache no processo de bundler.
COPY Gemfile Gemfile.lock ./
# Instalar bundler de requisito da aplicação.
RUN gem install bundler:2.2.15 \
    && bundle config set without 'development test' \
    && bundle install --jobs 20 --retry 5 \
    && rm -rf /usr/local/bundle/cache/*.gem \
    && find /usr/local/bundle/ -name "*.c" -delete \
    && find /usr/local/bundle/ -name "*.o" -delete
# Copiar toda aplicação para o WORKDIR
COPY . .
# Gerar os assets  da aplicação
RUN bundle exec rake assets:precompile && yarn cache clean

# Final Build
FROM ruby:2.7.2-alpine 
# Definir variáveis da aplicação
ENV RAILS_ENV='production'
ENV SECRET_KEY_BASE=dummy
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_ROOT  /app
ENV PORT=5000
# Instala depedências
RUN apk add --update --no-cache \
    openssl \
    tzdata \
    postgresql-dev \
    postgresql-client && rm -rf /var/cache/apk/*
# Criar diretório de trabalho
RUN mkdir $RAILS_ROOT
# Definir diretório de trabalho padrão.
WORKDIR $RAILS_ROOT
# Copiar os arquivos
COPY --from=pre-builder /usr/local/bundle /usr/local/bundle
COPY --from=pre-builder /app/ /app/
# Expor a porta externamente
EXPOSE $PORT
# Iniciar a aplicação 
CMD ["rails", "server", "-b", "0.0.0.0"]
