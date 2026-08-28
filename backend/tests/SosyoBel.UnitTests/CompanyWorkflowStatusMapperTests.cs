using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class CompanyWorkflowStatusMapperTests
{
    [Theory]
    [InlineData("Bekliyor", WorkItemStatusCodes.Pending, false)]
    [InlineData("Onaya Gönderildi", WorkItemStatusCodes.BoardPending, false)]
    [InlineData("Onaylandı", WorkItemStatusCodes.Completed, true)]
    [InlineData("Reddedildi", WorkItemStatusCodes.Rejected, true)]
    [InlineData("İptal Edildi", WorkItemStatusCodes.Canceled, true)]
    [InlineData("Yeni Bir Durum", WorkItemStatusCodes.Unknown, false)]
    public void FieldTaskStatusUsesCompanyWebValues(
        string companyStatus,
        string expectedCode,
        bool expectedCompleted)
    {
        var code = CompanyWorkflowStatusMapper.MapFieldTask(companyStatus);

        Assert.Equal(expectedCode, code);
        Assert.Equal(expectedCompleted, CompanyWorkflowStatusMapper.IsFieldTaskCompleted(code));
    }

    [Theory]
    [InlineData("Taslak", "TASLAK", false)]
    [InlineData("Kurul Bekliyor", WorkItemStatusCodes.BoardPending, false)]
    [InlineData("Beklemede", WorkItemStatusCodes.BoardPending, false)]
    [InlineData("Kişi Oluşturuldu", WorkItemStatusCodes.Completed, true)]
    [InlineData("İptal Edildi", WorkItemStatusCodes.Canceled, true)]
    [InlineData("Yardım Onaylandı", WorkItemStatusCodes.Completed, true)]
    [InlineData("Yardım Reddedildi", WorkItemStatusCodes.Rejected, true)]
    [InlineData("Yeni Bir Durum", WorkItemStatusCodes.Unknown, false)]
    public void ApplicationStatusUsesCompanyStatusNames(
        string companyStatus,
        string expectedCode,
        bool expectedCompleted)
    {
        var code = CompanyWorkflowStatusMapper.MapApplication(companyStatus);

        Assert.Equal(expectedCode, code);
        Assert.Equal(
            expectedCompleted,
            CompanyWorkflowStatusMapper.IsApplicationCompleted(code));
    }
}
