enum AccountRole {
  brand,
  community,
  space;

  String get label => switch (this) {
    AccountRole.brand => 'Brand',
    AccountRole.community => 'Community',
    AccountRole.space => 'Space',
  };

  String get backendAccountType => switch (this) {
    AccountRole.brand => 'BRAND',
    AccountRole.community => 'HOST',
    AccountRole.space => 'SPACE',
  };

  String get description => switch (this) {
    AccountRole.brand => 'Partner with communities and build experiences.',
    AccountRole.community => 'Host events and grow your community.',
    AccountRole.space => 'List and manage your event spaces.',
  };
}
