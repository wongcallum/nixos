{ self, lib, ... }:
{
  flake.modules = lib.mkMerge [
    (self.factory.user "colin" true false)
    {
      nixos.colin.users.users.colin.openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDvdpq/N0s0ldIe9Bp9oklODXf3dzwTL4XL1gZg1AJujSnhz1yJHhKv6pMmRvf9H+znzxWAB6BWAULMp5aWob3wVbgSRrxwXXEGVKinnBWZ6Ob7Ax/qFgk7jRMRwdnXWpLMQFmo63CVJJEpuVrVVxoJgMqFLJ22fhOckzuet+W/h2zh5eGntKuxE1P5rd4DnkAmz2xrXPcSHpRYuBQLuUer5PMtucTue6bUazomQXtUv269pBprYz+awnLsI9TOaX3Vpr3OWUN84fIylzWukYiaU0NlfMni9MP+WJgaenaCPa/f0c+hLNuETp23/I5lOVyPOKLD829pfmB3OvcWYcP6HxNRs+Dc126IpqNYek2bmJvuRiYINmPdZOmbGSNzQ43StGPw/vo/XeII/8GMWQgFFOT0HSpXr2xlr0HVxDzRS4mxRZrEHk3qOCuIq4Hpbr7/FM+CG5Akpgyk9svKki3YlzjmjWwJjbzXsMURnYTut454ord5MVTLZBoaG1Oxobk= colin@Colins-MacBook-Pro.local"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6n1HSJM7pm2qzSiHLu/lcCm9ZFmWEpflvuEDApmzZBV2hQrpP5lChC+z2uWi6Kz4vJSnRpyNHcpYKUy7DYd+B+uPRt38OYIOQXul4zEIpZczWyAsYxX+42uGf2IRtR8lgVSjbS0SA0oeRwIBMwtia9t1yp5vyXLq99/SThOg3NhVFA0Q0/OjCChEXLEYbuTfC0cmqlKYhadSbgAmxWORA2pvOao0D3XmsdrNQtMivuXYzTNqnUtap+at5zp4CYqN67YqksInGq1RGEPQKmWBGXvAM3uDhTvNqOwQKLN+9MgLpiAfPYOxtVjXpgKXQFdJBQrpMX3xrdXbUsKmcnovlFCNibHtgPYd7dPAC3jNTOJNi984PNpueC81eO98vMm9TtjEFi5oyQ6WbcNC0vjKkqzrsPvdByn6S3HaYW/mUcp31fI38ALxc+/WY8AwovalZOnBFzEssB8MyjbzaNMd26iucd6OUKyQlvPyOavbn2ZA7LRT0qV8gOiJ+5tn6kN8= colin@Jarrods-MacBook-Air.local"
      ];
    }
  ];
}
