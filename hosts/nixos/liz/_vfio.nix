# RTX 3060 passthrough for the Windows guest (Adobe + game streaming).
#
# Both functions have to be bound, not just the VGA one — the GA106 and its HDMI
# audio controller sit in the same IOMMU group, and vfio-pci will not take a
# group piecemeal:
#
#   10de:2504  GA106 [GeForce RTX 3060 Lite Hash Rate]
#   10de:228e  GA106 High Definition Audio Controller
#
# Binding at boot rather than at VM start is deliberate. Late binding via a
# libvirt hook would leave liz with a usable console the rest of the time, but
# that is the "passing through the boot GPU" case: the firmware framebuffer holds
# the card's aperture and NVIDIA reset is unreliable. staging/_remote-desktop.nix
# documents fighting exactly that. _console.nix buys back the console instead.
#
# Requires SVM + IOMMU enabled in the BIOS.
{
  boot = {
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "vfio-pci.ids=10de:2504,10de:228e"
    ];

    # Must load before any driver that would otherwise claim the card.
    initrd.kernelModules = [
      "vfio_pci"
      "vfio_iommu_type1"
      "vfio"
    ];
  };
}
