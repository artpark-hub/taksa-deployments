local claims = std.extVar('claims');

{
  identity: {
    traits: {
      email: claims.email,
      name: {
        first: if std.objectHas(claims, 'given_name') then claims.given_name else "",
        last: if std.objectHas(claims, 'family_name') then claims.family_name else "",
      },
    },
  },
}