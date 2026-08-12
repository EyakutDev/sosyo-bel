/*
  Cats Yazilim tarafindan paylasilan sosyaldb.ipynb dosyasindaki DDL'in
  mekanik SQL ciktisidir. Snapshot tarihi: 2026-08-03 19:17:54.

  Bu dosya yalniz BOS yerel gelistirme/test veritabani olusturmak icindir.
  Mevcut sirket veritabaninda calistirilmaz; canli/test hedefte once
  database/compatibility/000_inspect_company_schema.sql kullanilir.
  Veri INSERT'u icermez; dbo tablo, index, default ve foreign key DDL'ini korur.
*/

/****** Object:  Table [dbo].[__EFMigrationsHistory]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[__EFMigrationsHistory](
	[MigrationId] [nvarchar](150) NOT NULL,
	[ProductVersion] [nvarchar](32) NOT NULL,
 CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY CLUSTERED 
(
	[MigrationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AileFertleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AileFertleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NOT NULL,
	[AdSoyad] [nvarchar](max) NOT NULL,
	[Yas] [int] NOT NULL,
	[EngelDurumu] [bit] NOT NULL,
	[CalismaDurumuId] [int] NULL,
	[EgitimDurumuId] [int] NULL,
	[EngelTuruId] [int] NULL,
	[YakinlikId] [int] NOT NULL,
 CONSTRAINT [PK_AileFertleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetRoleClaims]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetRoleClaims](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RoleId] [nvarchar](450) NOT NULL,
	[ClaimType] [nvarchar](max) NULL,
	[ClaimValue] [nvarchar](max) NULL,
 CONSTRAINT [PK_AspNetRoleClaims] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetRoles]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetRoles](
	[Id] [nvarchar](450) NOT NULL,
	[Name] [nvarchar](256) NULL,
	[NormalizedName] [nvarchar](256) NULL,
	[ConcurrencyStamp] [nvarchar](max) NULL,
 CONSTRAINT [PK_AspNetRoles] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetUserClaims]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetUserClaims](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [nvarchar](450) NOT NULL,
	[ClaimType] [nvarchar](max) NULL,
	[ClaimValue] [nvarchar](max) NULL,
 CONSTRAINT [PK_AspNetUserClaims] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetUserLogins]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetUserLogins](
	[LoginProvider] [nvarchar](450) NOT NULL,
	[ProviderKey] [nvarchar](450) NOT NULL,
	[ProviderDisplayName] [nvarchar](max) NULL,
	[UserId] [nvarchar](450) NOT NULL,
 CONSTRAINT [PK_AspNetUserLogins] PRIMARY KEY CLUSTERED 
(
	[LoginProvider] ASC,
	[ProviderKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetUserRoles]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetUserRoles](
	[UserId] [nvarchar](450) NOT NULL,
	[RoleId] [nvarchar](450) NOT NULL,
 CONSTRAINT [PK_AspNetUserRoles] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetUsers]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetUsers](
	[Id] [nvarchar](450) NOT NULL,
	[Ad] [nvarchar](max) NOT NULL,
	[Soyad] [nvarchar](max) NOT NULL,
	[UserName] [nvarchar](256) NULL,
	[NormalizedUserName] [nvarchar](256) NULL,
	[Email] [nvarchar](256) NULL,
	[NormalizedEmail] [nvarchar](256) NULL,
	[EmailConfirmed] [bit] NOT NULL,
	[PasswordHash] [nvarchar](max) NULL,
	[SecurityStamp] [nvarchar](max) NULL,
	[ConcurrencyStamp] [nvarchar](max) NULL,
	[PhoneNumber] [nvarchar](max) NULL,
	[PhoneNumberConfirmed] [bit] NOT NULL,
	[TwoFactorEnabled] [bit] NOT NULL,
	[LockoutEnd] [datetimeoffset](7) NULL,
	[LockoutEnabled] [bit] NOT NULL,
	[AccessFailedCount] [int] NOT NULL,
 CONSTRAINT [PK_AspNetUsers] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[AspNetUserTokens]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AspNetUserTokens](
	[UserId] [nvarchar](450) NOT NULL,
	[LoginProvider] [nvarchar](450) NOT NULL,
	[Name] [nvarchar](450) NOT NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_AspNetUserTokens] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[LoginProvider] ASC,
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[BasvuruAileFertleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BasvuruAileFertleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BasvuruId] [int] NOT NULL,
	[AdSoyad] [nvarchar](max) NOT NULL,
	[Yas] [int] NOT NULL,
	[EngelDurumu] [bit] NOT NULL,
	[EngelTuruId] [int] NULL,
	[CalismaDurumuId] [int] NULL,
	[EgitimDurumuId] [int] NULL,
	[YakinlikId] [int] NOT NULL,
 CONSTRAINT [PK_BasvuruAileFertleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[BasvuruBelgeleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BasvuruBelgeleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BasvuruId] [int] NOT NULL,
	[BelgeAdi] [nvarchar](max) NOT NULL,
	[BelgeYolu] [nvarchar](max) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[YuklenmeTarihi] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_BasvuruBelgeleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[BasvuruDurumlari]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BasvuruDurumlari](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_BasvuruDurumlari] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Basvurular]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Basvurular](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NULL,
	[BasvuruTarihi] [datetime2](7) NOT NULL,
	[TalepAciklamasi] [nvarchar](max) NULL,
	[BasvuranAd] [nvarchar](max) NOT NULL,
	[BasvuruAcikAdres] [nvarchar](max) NULL,
	[BasvuranDogumTarihi] [nvarchar](max) NULL,
	[BasvuranSoyad] [nvarchar](max) NOT NULL,
	[BasvuranTcKimlikNo] [nvarchar](11) NOT NULL,
	[BasvuranTelefon] [nvarchar](max) NOT NULL,
	[HaneFotografYolu] [nvarchar](max) NULL,
	[IptalAciklamasi] [nvarchar](max) NULL,
	[IptalTarihi] [datetime2](7) NULL,
	[BasvuruDurumuId] [int] NOT NULL,
	[MahalleId] [int] NULL,
	[SokakId] [int] NULL,
	[YardimTuruId] [int] NOT NULL,
	[TalepGelisKanaliId] [int] NOT NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
	[EngelDurumu] [bit] NOT NULL,
	[EngelOrani] [int] NULL,
	[EngelTuruId] [int] NULL,
	[PublicToken] [nvarchar](32) NOT NULL,
	[BasvuranCinsiyet] [nvarchar](max) NULL,
	[BasvuranDogumYeri] [nvarchar](max) NULL,
	[BasvuranMedeniHal] [nvarchar](max) NULL,
	[BasvuruMahalle] [nvarchar](max) NULL,
	[BasvuruSokak] [nvarchar](max) NULL,
	[IlKodu] [int] NULL,
	[IlceKodu] [int] NULL,
	[MahalleKodu] [int] NULL,
	[SokakKodu] [int] NULL,
	[AdresNo] [bigint] NULL,
 CONSTRAINT [PK_Basvurular] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[CalismaDurumlari]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CalismaDurumlari](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_CalismaDurumlari] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[EgitimDurumlari]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EgitimDurumlari](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_EgitimDurumlari] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[EngelTurleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EngelTurleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_EngelTurleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[HaneFotograflari]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[HaneFotograflari](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NOT NULL,
	[FotografYolu] [nvarchar](max) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[YuklenmeTarihi] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_HaneFotograflari] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[IslemGecmisleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IslemGecmisleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BasvuruId] [int] NULL,
	[VatandasId] [int] NULL,
	[SosyalYardimId] [int] NULL,
	[IslemTipi] [nvarchar](100) NOT NULL,
	[OncekiDurum] [nvarchar](100) NULL,
	[YeniDurum] [nvarchar](100) NULL,
	[Aciklama] [nvarchar](max) NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
	[OlusturulmaTarihi] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_IslemGecmisleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[KurulIslemleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[KurulIslemleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NOT NULL,
	[Durum] [nvarchar](50) NOT NULL,
	[KurulOnayTarihi] [datetime2](7) NULL,
	[IslemTipi] [nvarchar](100) NOT NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
	[OlusturulmaTarihi] [datetime2](7) NOT NULL,
	[ReddetmeSebebi] [nvarchar](max) NULL,
	[Sebep] [nvarchar](max) NULL,
 CONSTRAINT [PK_KurulIslemleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Mahalle]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mahalle](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Ad] [nvarchar](250) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Mahalleler]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mahalleler](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_Mahalleler] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[MedeniDurumlar]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MedeniDurumlar](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_MedeniDurumlar] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Paketler]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Paketler](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PaketAdi] [nvarchar](max) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[OlusturmaTarihi] [datetime2](7) NOT NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
 CONSTRAINT [PK_Paketler] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[PaketUrunler]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PaketUrunler](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PaketId] [int] NOT NULL,
	[UrunId] [int] NOT NULL,
	[Miktar] [int] NOT NULL,
 CONSTRAINT [PK_PaketUrunler] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[SahaAktiviteleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SahaAktiviteleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NOT NULL,
	[PersonelId] [nvarchar](450) NOT NULL,
	[Aciklama] [nvarchar](max) NOT NULL,
	[Durum] [nvarchar](max) NOT NULL,
	[ReddetmeSebebi] [nvarchar](max) NULL,
	[OlusturulmaTarihi] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SahaAktiviteleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[SistemAyarlari]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SistemAyarlari](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BelediyeAdi] [nvarchar](max) NOT NULL,
	[LogoYolu] [nvarchar](max) NOT NULL,
	[KurulModuluAktif] [bit] NOT NULL,
 CONSTRAINT [PK_SistemAyarlari] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Sokak]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Sokak](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[MahalleId] [int] NOT NULL,
	[Ad] [nvarchar](250) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Sokaklar]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Sokaklar](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[MahalleId] [int] NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_Sokaklar] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[SosyalYardimlar]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SosyalYardimlar](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NOT NULL,
	[BasvuruId] [int] NULL,
	[BaslangicTarihi] [datetime2](7) NOT NULL,
	[BitisTarihi] [datetime2](7) NULL,
	[Miktar] [decimal](18, 2) NOT NULL,
	[Birim] [nvarchar](max) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[TamamlanmaOrani] [int] NOT NULL,
	[Durum] [int] NOT NULL,
	[ReddetmeSebebi] [nvarchar](max) NULL,
	[PaketId] [int] NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
	[YardimSekliId] [int] NOT NULL,
	[YardimTipiId] [int] NOT NULL,
	[YardimTuruId] [int] NULL,
	[OnayAciklamasi] [nvarchar](max) NULL,
 CONSTRAINT [PK_SosyalYardimlar] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[StokHareketleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StokHareketleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[StokUrunId] [int] NOT NULL,
	[SosyalYardimId] [int] NULL,
	[Miktar] [int] NOT NULL,
	[HareketTipi] [nvarchar](50) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
	[Tarih] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_StokHareketleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[StokUrunler]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StokUrunler](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UrunAdi] [nvarchar](max) NOT NULL,
	[Miktar] [int] NOT NULL,
	[Birim] [nvarchar](max) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[OlusturmaTarihi] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_StokUrunler] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[TalepGelisKanallari]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TalepGelisKanallari](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_TalepGelisKanallari] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[VatandasBelgeler]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VatandasBelgeler](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VatandasId] [int] NOT NULL,
	[BelgeAdi] [nvarchar](max) NOT NULL,
	[BelgeYolu] [nvarchar](max) NOT NULL,
	[Aciklama] [nvarchar](max) NULL,
	[YuklenmeTarihi] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_VatandaÅŸBelgeler] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Vatandaslar]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vatandaslar](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[TcKimlikNo] [nvarchar](11) NOT NULL,
	[Ad] [nvarchar](max) NOT NULL,
	[Soyad] [nvarchar](max) NOT NULL,
	[DogumTarihi] [datetime2](7) NOT NULL,
	[AcikAdres] [nvarchar](max) NOT NULL,
	[Telefon1] [nvarchar](max) NOT NULL,
	[Telefon2] [nvarchar](max) NULL,
	[Email] [nvarchar](max) NULL,
	[EngelDurumu] [bit] NOT NULL,
	[EngelOrani] [int] NULL,
	[CocukSayisi] [int] NULL,
	[KayitTarihi] [datetime2](7) NOT NULL,
	[MahalleId] [int] NOT NULL,
	[SokakId] [int] NULL,
	[OlusturanUserId] [nvarchar](450) NULL,
	[Sil] [bit] NOT NULL,
	[CalismaDurumuId] [int] NULL,
	[EgitimDurumuId] [int] NULL,
	[EngelTuruId] [int] NULL,
	[MedeniDurumId] [int] NULL,
	[Cinsiyet] [nvarchar](max) NULL,
	[DogumYeri] [nvarchar](max) NULL,
	[IlKodu] [int] NULL,
	[IlceKodu] [int] NULL,
	[KpsMahalle] [nvarchar](max) NULL,
	[KpsSokak] [nvarchar](max) NULL,
	[MahalleKodu] [int] NULL,
	[SokakKodu] [int] NULL,
	[AdresNo] [bigint] NULL,
 CONSTRAINT [PK_Vatandaslar] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Yakinliklar]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Yakinliklar](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_Yakinliklar] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[YardimSekilleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[YardimSekilleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_YardimSekilleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[YardimTipleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[YardimTipleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_YardimTipleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[YardimTurleri]    Script Date: 3.08.2026 19:17:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[YardimTurleri](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Sil] [bit] NOT NULL,
 CONSTRAINT [PK_YardimTurleri] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[AileFertleri] ADD  DEFAULT (CONVERT([bit],(0))) FOR [EngelDurumu]
GO

ALTER TABLE [dbo].[Basvurular] ADD  DEFAULT (N'') FOR [BasvuranAd]
GO

ALTER TABLE [dbo].[Basvurular] ADD  DEFAULT (N'') FOR [BasvuranSoyad]
GO

ALTER TABLE [dbo].[Basvurular] ADD  DEFAULT (N'') FOR [BasvuranTelefon]
GO

ALTER TABLE [dbo].[Basvurular] ADD  DEFAULT (CONVERT([bit],(0))) FOR [EngelDurumu]
GO

ALTER TABLE [dbo].[Basvurular] ADD  DEFAULT (N'') FOR [PublicToken]
GO

ALTER TABLE [dbo].[KurulIslemleri] ADD  DEFAULT (N'') FOR [IslemTipi]
GO

ALTER TABLE [dbo].[KurulIslemleri] ADD  DEFAULT ('0001-01-01T00:00:00.0000000') FOR [OlusturulmaTarihi]
GO

ALTER TABLE [dbo].[SosyalYardimlar] ADD  DEFAULT ((1)) FOR [YardimSekliId]
GO

ALTER TABLE [dbo].[SosyalYardimlar] ADD  DEFAULT ((1)) FOR [YardimTipiId]
GO

ALTER TABLE [dbo].[Vatandaslar] ADD  DEFAULT (CONVERT([bit],(0))) FOR [EngelDurumu]
GO

ALTER TABLE [dbo].[Vatandaslar] ADD  DEFAULT (CONVERT([bit],(1))) FOR [Sil]
GO

ALTER TABLE [dbo].[AileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_AileFertleri_CalismaDurumlari_CalismaDurumuId] FOREIGN KEY([CalismaDurumuId])
REFERENCES [dbo].[CalismaDurumlari] ([Id])
GO
ALTER TABLE [dbo].[AileFertleri] CHECK CONSTRAINT [FK_AileFertleri_CalismaDurumlari_CalismaDurumuId]
GO

ALTER TABLE [dbo].[AileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_AileFertleri_EgitimDurumlari_EgitimDurumuId] FOREIGN KEY([EgitimDurumuId])
REFERENCES [dbo].[EgitimDurumlari] ([Id])
GO
ALTER TABLE [dbo].[AileFertleri] CHECK CONSTRAINT [FK_AileFertleri_EgitimDurumlari_EgitimDurumuId]
GO

ALTER TABLE [dbo].[AileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_AileFertleri_EngelTurleri_EngelTuruId] FOREIGN KEY([EngelTuruId])
REFERENCES [dbo].[EngelTurleri] ([Id])
GO
ALTER TABLE [dbo].[AileFertleri] CHECK CONSTRAINT [FK_AileFertleri_EngelTurleri_EngelTuruId]
GO

ALTER TABLE [dbo].[AileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_AileFertleri_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AileFertleri] CHECK CONSTRAINT [FK_AileFertleri_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[AileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_AileFertleri_Yakinliklar_YakinlikId] FOREIGN KEY([YakinlikId])
REFERENCES [dbo].[Yakinliklar] ([Id])
GO
ALTER TABLE [dbo].[AileFertleri] CHECK CONSTRAINT [FK_AileFertleri_Yakinliklar_YakinlikId]
GO

ALTER TABLE [dbo].[AspNetRoleClaims]  WITH CHECK ADD  CONSTRAINT [FK_AspNetRoleClaims_AspNetRoles_RoleId] FOREIGN KEY([RoleId])
REFERENCES [dbo].[AspNetRoles] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AspNetRoleClaims] CHECK CONSTRAINT [FK_AspNetRoleClaims_AspNetRoles_RoleId]
GO

ALTER TABLE [dbo].[AspNetUserClaims]  WITH CHECK ADD  CONSTRAINT [FK_AspNetUserClaims_AspNetUsers_UserId] FOREIGN KEY([UserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AspNetUserClaims] CHECK CONSTRAINT [FK_AspNetUserClaims_AspNetUsers_UserId]
GO

ALTER TABLE [dbo].[AspNetUserLogins]  WITH CHECK ADD  CONSTRAINT [FK_AspNetUserLogins_AspNetUsers_UserId] FOREIGN KEY([UserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AspNetUserLogins] CHECK CONSTRAINT [FK_AspNetUserLogins_AspNetUsers_UserId]
GO

ALTER TABLE [dbo].[AspNetUserRoles]  WITH CHECK ADD  CONSTRAINT [FK_AspNetUserRoles_AspNetRoles_RoleId] FOREIGN KEY([RoleId])
REFERENCES [dbo].[AspNetRoles] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AspNetUserRoles] CHECK CONSTRAINT [FK_AspNetUserRoles_AspNetRoles_RoleId]
GO

ALTER TABLE [dbo].[AspNetUserRoles]  WITH CHECK ADD  CONSTRAINT [FK_AspNetUserRoles_AspNetUsers_UserId] FOREIGN KEY([UserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AspNetUserRoles] CHECK CONSTRAINT [FK_AspNetUserRoles_AspNetUsers_UserId]
GO

ALTER TABLE [dbo].[AspNetUserTokens]  WITH CHECK ADD  CONSTRAINT [FK_AspNetUserTokens_AspNetUsers_UserId] FOREIGN KEY([UserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AspNetUserTokens] CHECK CONSTRAINT [FK_AspNetUserTokens_AspNetUsers_UserId]
GO

ALTER TABLE [dbo].[BasvuruAileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_BasvuruAileFertleri_Basvurular_BasvuruId] FOREIGN KEY([BasvuruId])
REFERENCES [dbo].[Basvurular] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[BasvuruAileFertleri] CHECK CONSTRAINT [FK_BasvuruAileFertleri_Basvurular_BasvuruId]
GO

ALTER TABLE [dbo].[BasvuruAileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_BasvuruAileFertleri_CalismaDurumlari_CalismaDurumuId] FOREIGN KEY([CalismaDurumuId])
REFERENCES [dbo].[CalismaDurumlari] ([Id])
GO
ALTER TABLE [dbo].[BasvuruAileFertleri] CHECK CONSTRAINT [FK_BasvuruAileFertleri_CalismaDurumlari_CalismaDurumuId]
GO

ALTER TABLE [dbo].[BasvuruAileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_BasvuruAileFertleri_EgitimDurumlari_EgitimDurumuId] FOREIGN KEY([EgitimDurumuId])
REFERENCES [dbo].[EgitimDurumlari] ([Id])
GO
ALTER TABLE [dbo].[BasvuruAileFertleri] CHECK CONSTRAINT [FK_BasvuruAileFertleri_EgitimDurumlari_EgitimDurumuId]
GO

ALTER TABLE [dbo].[BasvuruAileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_BasvuruAileFertleri_EngelTurleri_EngelTuruId] FOREIGN KEY([EngelTuruId])
REFERENCES [dbo].[EngelTurleri] ([Id])
GO
ALTER TABLE [dbo].[BasvuruAileFertleri] CHECK CONSTRAINT [FK_BasvuruAileFertleri_EngelTurleri_EngelTuruId]
GO

ALTER TABLE [dbo].[BasvuruAileFertleri]  WITH CHECK ADD  CONSTRAINT [FK_BasvuruAileFertleri_Yakinliklar_YakinlikId] FOREIGN KEY([YakinlikId])
REFERENCES [dbo].[Yakinliklar] ([Id])
GO
ALTER TABLE [dbo].[BasvuruAileFertleri] CHECK CONSTRAINT [FK_BasvuruAileFertleri_Yakinliklar_YakinlikId]
GO

ALTER TABLE [dbo].[BasvuruBelgeleri]  WITH CHECK ADD  CONSTRAINT [FK_BasvuruBelgeleri_Basvurular_BasvuruId] FOREIGN KEY([BasvuruId])
REFERENCES [dbo].[Basvurular] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[BasvuruBelgeleri] CHECK CONSTRAINT [FK_BasvuruBelgeleri_Basvurular_BasvuruId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_BasvuruDurumlari_BasvuruDurumuId] FOREIGN KEY([BasvuruDurumuId])
REFERENCES [dbo].[BasvuruDurumlari] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_BasvuruDurumlari_BasvuruDurumuId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_EngelTurleri_EngelTuruId] FOREIGN KEY([EngelTuruId])
REFERENCES [dbo].[EngelTurleri] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_EngelTurleri_EngelTuruId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_Mahalleler_MahalleId] FOREIGN KEY([MahalleId])
REFERENCES [dbo].[Mahalleler] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_Mahalleler_MahalleId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_Sokaklar_SokakId] FOREIGN KEY([SokakId])
REFERENCES [dbo].[Sokaklar] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_Sokaklar_SokakId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_TalepGelisKanallari_TalepGelisKanaliId] FOREIGN KEY([TalepGelisKanaliId])
REFERENCES [dbo].[TalepGelisKanallari] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_TalepGelisKanallari_TalepGelisKanaliId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[Basvurular]  WITH CHECK ADD  CONSTRAINT [FK_Basvurular_YardimTurleri_YardimTuruId] FOREIGN KEY([YardimTuruId])
REFERENCES [dbo].[YardimTurleri] ([Id])
GO
ALTER TABLE [dbo].[Basvurular] CHECK CONSTRAINT [FK_Basvurular_YardimTurleri_YardimTuruId]
GO

ALTER TABLE [dbo].[HaneFotograflari]  WITH CHECK ADD  CONSTRAINT [FK_HaneFotograflari_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[HaneFotograflari] CHECK CONSTRAINT [FK_HaneFotograflari_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[IslemGecmisleri]  WITH CHECK ADD  CONSTRAINT [FK_IslemGecmisleri_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[IslemGecmisleri] CHECK CONSTRAINT [FK_IslemGecmisleri_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[IslemGecmisleri]  WITH CHECK ADD  CONSTRAINT [FK_IslemGecmisleri_Basvurular_BasvuruId] FOREIGN KEY([BasvuruId])
REFERENCES [dbo].[Basvurular] ([Id])
GO
ALTER TABLE [dbo].[IslemGecmisleri] CHECK CONSTRAINT [FK_IslemGecmisleri_Basvurular_BasvuruId]
GO

ALTER TABLE [dbo].[IslemGecmisleri]  WITH CHECK ADD  CONSTRAINT [FK_IslemGecmisleri_SosyalYardimlar_SosyalYardimId] FOREIGN KEY([SosyalYardimId])
REFERENCES [dbo].[SosyalYardimlar] ([Id])
GO
ALTER TABLE [dbo].[IslemGecmisleri] CHECK CONSTRAINT [FK_IslemGecmisleri_SosyalYardimlar_SosyalYardimId]
GO

ALTER TABLE [dbo].[IslemGecmisleri]  WITH CHECK ADD  CONSTRAINT [FK_IslemGecmisleri_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
GO
ALTER TABLE [dbo].[IslemGecmisleri] CHECK CONSTRAINT [FK_IslemGecmisleri_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[KurulIslemleri]  WITH CHECK ADD  CONSTRAINT [FK_KurulIslemleri_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[KurulIslemleri] CHECK CONSTRAINT [FK_KurulIslemleri_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[KurulIslemleri]  WITH CHECK ADD  CONSTRAINT [FK_KurulIslemleri_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[KurulIslemleri] CHECK CONSTRAINT [FK_KurulIslemleri_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[Paketler]  WITH CHECK ADD  CONSTRAINT [FK_Paketler_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[Paketler] CHECK CONSTRAINT [FK_Paketler_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[PaketUrunler]  WITH CHECK ADD  CONSTRAINT [FK_PaketUrunler_Paketler_PaketId] FOREIGN KEY([PaketId])
REFERENCES [dbo].[Paketler] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PaketUrunler] CHECK CONSTRAINT [FK_PaketUrunler_Paketler_PaketId]
GO

ALTER TABLE [dbo].[PaketUrunler]  WITH CHECK ADD  CONSTRAINT [FK_PaketUrunler_StokUrunler_UrunId] FOREIGN KEY([UrunId])
REFERENCES [dbo].[StokUrunler] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PaketUrunler] CHECK CONSTRAINT [FK_PaketUrunler_StokUrunler_UrunId]
GO

ALTER TABLE [dbo].[SahaAktiviteleri]  WITH CHECK ADD  CONSTRAINT [FK_SahaAktiviteleri_AspNetUsers_PersonelId] FOREIGN KEY([PersonelId])
REFERENCES [dbo].[AspNetUsers] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[SahaAktiviteleri] CHECK CONSTRAINT [FK_SahaAktiviteleri_AspNetUsers_PersonelId]
GO

ALTER TABLE [dbo].[SahaAktiviteleri]  WITH CHECK ADD  CONSTRAINT [FK_SahaAktiviteleri_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[SahaAktiviteleri] CHECK CONSTRAINT [FK_SahaAktiviteleri_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[Sokak]  WITH CHECK ADD  CONSTRAINT [FK_Sokak_Mahalle] FOREIGN KEY([MahalleId])
REFERENCES [dbo].[Mahalle] ([Id])
GO
ALTER TABLE [dbo].[Sokak] CHECK CONSTRAINT [FK_Sokak_Mahalle]
GO

ALTER TABLE [dbo].[Sokaklar]  WITH CHECK ADD  CONSTRAINT [FK_Sokaklar_Mahalleler_MahalleId] FOREIGN KEY([MahalleId])
REFERENCES [dbo].[Mahalleler] ([Id])
GO
ALTER TABLE [dbo].[Sokaklar] CHECK CONSTRAINT [FK_Sokaklar_Mahalleler_MahalleId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_Basvurular_BasvuruId] FOREIGN KEY([BasvuruId])
REFERENCES [dbo].[Basvurular] ([Id])
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_Basvurular_BasvuruId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_Paketler_PaketId] FOREIGN KEY([PaketId])
REFERENCES [dbo].[Paketler] ([Id])
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_Paketler_PaketId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_YardimSekilleri_YardimSekliId] FOREIGN KEY([YardimSekliId])
REFERENCES [dbo].[YardimSekilleri] ([Id])
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_YardimSekilleri_YardimSekliId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_YardimTipleri_YardimTipiId] FOREIGN KEY([YardimTipiId])
REFERENCES [dbo].[YardimTipleri] ([Id])
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_YardimTipleri_YardimTipiId]
GO

ALTER TABLE [dbo].[SosyalYardimlar]  WITH CHECK ADD  CONSTRAINT [FK_SosyalYardimlar_YardimTurleri_YardimTuruId] FOREIGN KEY([YardimTuruId])
REFERENCES [dbo].[YardimTurleri] ([Id])
GO
ALTER TABLE [dbo].[SosyalYardimlar] CHECK CONSTRAINT [FK_SosyalYardimlar_YardimTurleri_YardimTuruId]
GO

ALTER TABLE [dbo].[StokHareketleri]  WITH CHECK ADD  CONSTRAINT [FK_StokHareketleri_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[StokHareketleri] CHECK CONSTRAINT [FK_StokHareketleri_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[StokHareketleri]  WITH CHECK ADD  CONSTRAINT [FK_StokHareketleri_SosyalYardimlar_SosyalYardimId] FOREIGN KEY([SosyalYardimId])
REFERENCES [dbo].[SosyalYardimlar] ([Id])
GO
ALTER TABLE [dbo].[StokHareketleri] CHECK CONSTRAINT [FK_StokHareketleri_SosyalYardimlar_SosyalYardimId]
GO

ALTER TABLE [dbo].[StokHareketleri]  WITH CHECK ADD  CONSTRAINT [FK_StokHareketleri_StokUrunler_StokUrunId] FOREIGN KEY([StokUrunId])
REFERENCES [dbo].[StokUrunler] ([Id])
GO
ALTER TABLE [dbo].[StokHareketleri] CHECK CONSTRAINT [FK_StokHareketleri_StokUrunler_StokUrunId]
GO

ALTER TABLE [dbo].[VatandasBelgeler]  WITH CHECK ADD  CONSTRAINT [FK_VatandaÅŸBelgeler_Vatandaslar_VatandasId] FOREIGN KEY([VatandasId])
REFERENCES [dbo].[Vatandaslar] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[VatandasBelgeler] CHECK CONSTRAINT [FK_VatandaÅŸBelgeler_Vatandaslar_VatandasId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_AspNetUsers_OlusturanUserId] FOREIGN KEY([OlusturanUserId])
REFERENCES [dbo].[AspNetUsers] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_AspNetUsers_OlusturanUserId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_CalismaDurumlari_CalismaDurumuId] FOREIGN KEY([CalismaDurumuId])
REFERENCES [dbo].[CalismaDurumlari] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_CalismaDurumlari_CalismaDurumuId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_EgitimDurumlari_EgitimDurumuId] FOREIGN KEY([EgitimDurumuId])
REFERENCES [dbo].[EgitimDurumlari] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_EgitimDurumlari_EgitimDurumuId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_EngelTurleri_EngelTuruId] FOREIGN KEY([EngelTuruId])
REFERENCES [dbo].[EngelTurleri] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_EngelTurleri_EngelTuruId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_Mahalleler_MahalleId] FOREIGN KEY([MahalleId])
REFERENCES [dbo].[Mahalleler] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_Mahalleler_MahalleId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_MedeniDurumlar_MedeniDurumId] FOREIGN KEY([MedeniDurumId])
REFERENCES [dbo].[MedeniDurumlar] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_MedeniDurumlar_MedeniDurumId]
GO

ALTER TABLE [dbo].[Vatandaslar]  WITH CHECK ADD  CONSTRAINT [FK_Vatandaslar_Sokaklar_SokakId] FOREIGN KEY([SokakId])
REFERENCES [dbo].[Sokaklar] ([Id])
GO
ALTER TABLE [dbo].[Vatandaslar] CHECK CONSTRAINT [FK_Vatandaslar_Sokaklar_SokakId]
GO
