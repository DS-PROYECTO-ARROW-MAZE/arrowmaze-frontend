---
name: nestjs-patterns
description: NestJS architecture patterns for modules, controllers, providers, DTO validation, guards, interceptors, config, and production-grade TypeScript backends.
origin: ECC
---

# NestJS Development Patterns

Production-grade NestJS patterns for modular TypeScript backends.

## When to Activate

- Building NestJS APIs or services
- Structuring modules, controllers, and providers
- Adding DTO validation, guards, interceptors, or exception filters
- Configuring environment-aware settings and database integrations
- Testing NestJS units or HTTP endpoints

## Project Structure

Hexagonal architecture (Ports & Adapters): the domain has zero framework dependencies; application defines use cases and ports; infrastructure wires everything together.

```text
prisma/                              ← Prisma lives at the project root, NOT inside src/
├── schema.prisma                    ← datasource (Supabase Postgres), generator, models
├── migrations/                      ← versioned migrations (prisma migrate)
└── seed.ts                          ← optional seed script

src/
├── app.module.ts
├── main.ts
│
├── domain/                          ← pure TypeScript, no NestJS/Prisma imports
│   ├── entities/                    ← aggregates & entities (NOT Prisma models)
│   ├── value-objects/               ← value objects with validating factories
│   ├── events/                      ← domain events raised by aggregates
│   ├── repositories/                ← repository interfaces (driven ports)
│   └── services/                    ← stateless domain logic (optional; for rules
│                                       that don't belong to a single aggregate)
│
├── application/                     ← depends on domain only
│   ├── use-cases/                   ← one class per use case (implement the use-case contract)
│   ├── dtos/                        ← input/output contracts
│   ├── ports/                       ← driven-side interfaces (hash, token, events,
│   │                                  unit-of-work, read-model queries, …)
│   ├── mappers/                     ← domain ↔ DTO conversion
│   └── decorators/                  ← AOP use-case decorators (logging, metrics) that
│                                       wrap the use-case contract — NOT NestJS HTTP interceptors
│
└── infrastructure/                  ← framework + third-party glue
    ├── adapters/
    │   ├── http/                    ← driving adapters (NestJS HTTP)
    │   │   ├── controllers/
    │   │   ├── guards/
    │   │   ├── filters/
    │   │   ├── interceptors/        ← NestJS HTTP interceptors (distinct from application/decorators/)
    │   │   └── pipes/
    │   ├── persistence/             ← driven adapters backed by Prisma
    │   │   ├── prisma/              ← PrismaService (extends PrismaClient) + module
    │   │   ├── repositories/        ← implement domain repo interfaces via Prisma (return aggregates)
    │   │   ├── mappers/             ← Prisma row ↔ domain aggregate conversion
    │   │   ├── queries/             ← read-model adapters (Prisma/raw SQL → response DTOs)
    │   │   └── unit-of-work/        ← transaction boundary wrapping prisma.$transaction
    │   ├── security/                ← driven adapters for auth ports (hashing, token signing)
    │   └── events/                  ← driven adapter that publishes domain events
    ├── config/
    │   ├── configuration.ts
    │   └── validation.ts
    └── modules/                     ← NestJS module wiring
```

- `domain/` must never import from `application/`, `infrastructure/`, NestJS, or Prisma. Domain entities are hand-written aggregates, **not** the types Prisma generates.
- `application/` imports only from `domain/`. Use cases depend on repository and port interfaces, not implementations.
- `infrastructure/` is the only layer that imports NestJS decorators and the Prisma client.
- The Prisma schema and migrations live in a root-level `prisma/` folder (Prisma's convention), separate from `src/`. The generated client is the default `@prisma/client`.
- Controllers live in `infrastructure/adapters/http/` — they are adapters, not domain logic.
- Repository implementations in `infrastructure/adapters/persistence/repositories/` implement the interfaces from `domain/repositories/` using the injected `PrismaService`, and use `persistence/mappers/` to translate Prisma rows ↔ domain aggregates (so Prisma types never leak past this layer).
- One adapter folder per port category: `persistence/` (prisma client, repositories, mappers, queries, unit-of-work), `security/` (hash, token), `events/` (publisher). Add more as new ports appear.
- **Two different "interceptor" concepts:** application-level AOP decorators that wrap the use-case contract live in `application/decorators/`; NestJS request/response interceptors live in `infrastructure/adapters/http/interceptors/`. Don't conflate them.
- Read-model queries (e.g. ranking/leaderboard) return DTOs and live in `persistence/queries/`, separate from aggregate-returning `repositories/`.

## Bootstrap and Global Validation

```ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));
  app.useGlobalFilters(new HttpExceptionFilter());

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
```

- Always enable `whitelist` and `forbidNonWhitelisted` on public APIs.
- Prefer one global validation pipe instead of repeating validation config per route.

## Modules, Controllers, and Providers

Each feature is wired in `infrastructure/modules/`. The controller delegates to an application use case; the use case depends on a domain repository interface that the infrastructure repository implements.

```ts
// infrastructure/modules/users.module.ts
@Module({
  imports: [PrismaModule],
  controllers: [UsersController],
  providers: [
    CreateUserUseCase,
    { provide: USER_REPOSITORY, useClass: PrismaUserRepository },
  ],
})
export class UsersModule {}

// infrastructure/adapters/http/controllers/users.controller.ts
@Controller('users')
export class UsersController {
  constructor(private readonly createUser: CreateUserUseCase) {}

  @Post()
  create(@Body() dto: CreateUserDto) {
    return this.createUser.execute(dto);
  }

  @Get(':id')
  getById(@Param('id', ParseUUIDPipe) id: string) {
    return this.createUser.getById(id);
  }
}

// application/use-cases/create-user.use-case.ts
@Injectable()
export class CreateUserUseCase {
  constructor(
    @Inject(USER_REPOSITORY) private readonly userRepo: IUserRepository,
  ) {}

  async execute(dto: CreateUserDto): Promise<UserResponseDto> {
    const user = User.create(dto);          // domain entity factory
    await this.userRepo.save(user);
    return UserMapper.toResponse(user);
  }
}

// domain/repositories/user.repository.interface.ts  (port)
export const USER_REPOSITORY = Symbol('USER_REPOSITORY');
export interface IUserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
}

// infrastructure/adapters/persistence/prisma/prisma.service.ts
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}

// infrastructure/adapters/persistence/repositories/prisma-user.repository.ts
@Injectable()
export class PrismaUserRepository implements IUserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async save(user: User): Promise<void> {
    const row = UserPrismaMapper.toPersistence(user);
    await this.prisma.user.upsert({ where: { id: row.id }, create: row, update: row });
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.prisma.user.findUnique({ where: { id } });
    return row ? UserPrismaMapper.toDomain(row) : null;
  }
}
```

- Controllers are thin HTTP adapters: parse input, call one use case, return the result.
- Use cases own business flow; they speak domain language and depend on interfaces, not concrete repos.
- Inject repository implementations via a Symbol token so use cases never import infrastructure.
- The repository receives `PrismaService` and maps Prisma rows to domain aggregates with a persistence mapper — Prisma types stay inside `persistence/`.

## DTOs and Validation

DTOs live in `application/dtos/` — they are the contract between the HTTP adapter and the use case. Domain entities must never be returned directly from controllers.

```ts
// application/dtos/create-user.dto.ts
export class CreateUserDto {
  @IsEmail()
  email!: string;

  @IsString()
  @Length(2, 80)
  name!: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}

// application/mappers/user.mapper.ts
export class UserMapper {
  static toResponse(user: User): UserResponseDto {
    return { id: user.id, email: user.email, name: user.name };
  }
}
```

- Validate every request DTO with `class-validator` at the HTTP adapter boundary.
- Use mappers in `application/mappers/` to convert domain entities to response DTOs.
- Avoid leaking internal fields such as password hashes, tokens, or audit columns.

## Auth, Guards, and Request Context

```ts
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Get('admin/report')
getAdminReport(@Req() req: AuthenticatedRequest) {
  return this.reportService.getForUser(req.user.id);
}
```

- Keep auth strategies and guards module-local unless they are truly shared.
- Encode coarse access rules in guards, then do resource-specific authorization in services.
- Prefer explicit request types for authenticated request objects.

## Exception Filters and Error Shape

```ts
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();
    const request = host.switchToHttp().getRequest<Request>();

    if (exception instanceof HttpException) {
      return response.status(exception.getStatus()).json({
        path: request.url,
        error: exception.getResponse(),
      });
    }

    return response.status(500).json({
      path: request.url,
      error: 'Internal server error',
    });
  }
}
```

- Keep one consistent error envelope across the API.
- Throw framework exceptions for expected client errors; log and wrap unexpected failures centrally.

## Config and Environment Validation

```ts
ConfigModule.forRoot({
  isGlobal: true,
  load: [configuration],
  validate: validateEnv,
});
```

- Validate env at boot, not lazily at first request.
- Keep config access behind typed helpers or config services.
- Split dev/staging/prod concerns in config factories instead of branching throughout feature code.

## Persistence and Transactions (Prisma)

- Define repository interfaces (ports) in `domain/repositories/` — no Prisma types, only domain entities.
- Implement those interfaces in `infrastructure/adapters/persistence/repositories/` using the injected `PrismaService` — this is the only place `@prisma/client` imports are allowed.
- Keep the Prisma schema and migrations in the root-level `prisma/` folder. Run `prisma generate` on install and `prisma migrate` for schema changes; never hand-edit generated client code.
- Map Prisma rows to domain aggregates in `persistence/mappers/` so generated Prisma model types never leak into `domain/` or `application/`.
- Wrap multi-step writes in `prisma.$transaction(...)` behind the `IUnidadDeTrabajo`/unit-of-work port (`persistence/unit-of-work/`); use cases coordinate the transaction, controllers never do.
- Expose a `PrismaModule` that provides and exports `PrismaService` so feature modules can inject it.

## Testing

```ts
describe('UsersController', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [UsersModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });
});
```

- Unit test providers in isolation with mocked dependencies.
- Add request-level tests for guards, validation pipes, and exception filters.
- Reuse the same global pipes/filters in tests that you use in production.

## Production Defaults

- Enable structured logging and request correlation ids.
- Terminate on invalid env/config instead of booting partially.
- Prefer async provider initialization for DB/cache clients with explicit health checks.
- Keep background jobs and event consumers in their own modules, not inside HTTP controllers.
- Make rate limiting, auth, and audit logging explicit for public endpoints.
