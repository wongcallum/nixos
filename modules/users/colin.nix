{ self, lib, ... }:
{
  flake.modules = lib.mkMerge [
    (self.factory.user "colin" true false)
    {
      nixos.colin.users.users.colin.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC2iI2HrNYTcubmMHil3MDRBI4mermU/o+37Gvx0zTse"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6n1HSJM7pm2qzSiHLu/lcCm9ZFmWEpflvuEDApmzZBV2hQrpP5lChC+z2uWi6Kz4vJSnRpyNHcpYKUy7DYd+B+uPRt38OYIOQXul4zEIpZczWyAsYxX+42uGf2IRtR8lgVSjbS0SA0oeRwIBMwtia9t1yp5vyXLq99/SThOg3NhVFA0Q0/OjCChEXLEYbuTfC0cmqlKYhadSbgAmxWORA2pvOao0D3XmsdrNQtMivuXYzTNqnUtap+at5zp4CYqN67YqksInGq1RGEPQKmWBGXvAM3uDhTvNqOwQKLN+9MgLpiAfPYOxtVjXpgKXQFdJBQrpMX3xrdXbUsKmcnovlFCNibHtgPYd7dPAC3jNTOJNi984PNpueC81eO98vMm9TtjEFi5oyQ6WbcNC0vjKkqzrsPvdByn6S3HaYW/mUcp31fI38ALxc+/WY8AwovalZOnBFzEssB8MyjbzaNMd26iucd6OUKyQlvPyOavbn2ZA7LRT0qV8gOiJ+5tn6kN8= colin@Jarrods-MacBook-Air.local"
      ];
    }
  ];
}
