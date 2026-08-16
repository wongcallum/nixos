{
  boot = {
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "vfio-pci.ids=10de:2504,10de:228e"
    ];

    initrd.kernelModules = [
      "vfio_pci"
      "vfio_iommu_type1"
      "vfio"
    ];
  };
}
