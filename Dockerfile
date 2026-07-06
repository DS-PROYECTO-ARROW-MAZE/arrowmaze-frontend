FROM debian:stable-slim AS build-env


RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa


RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"


RUN flutter doctor -v

WORKDIR /app
COPY . .

# Baked into the compiled JS at build time (Flutter web has no runtime env
# access) — override with --build-arg or the API_BASE_URL compose variable to
# point at wherever the backend is reachable from the browser.
ARG API_BASE_URL=http://localhost:3000

RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}


FROM nginx:alpine AS runner
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]