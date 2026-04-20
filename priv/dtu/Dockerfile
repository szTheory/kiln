FROM hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21 AS build

RUN apk add --no-cache git build-base
WORKDIR /build

ENV MIX_ENV=prod

COPY mix.exs ./
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get && mix deps.compile

COPY lib lib
COPY contracts contracts
RUN mix release kiln_dtu

FROM alpine:3.21

RUN apk add --no-cache ncurses-libs libstdc++ libgcc wget dnsmasq

COPY --from=build /build/_build/prod/rel/kiln_dtu /app
WORKDIR /app

EXPOSE 80

CMD ["/app/bin/kiln_dtu", "start"]
