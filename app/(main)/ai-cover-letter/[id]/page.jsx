// const CoverLetter = async({params}) => {
//     const id = await params.id ;
//     return <div>
//     CoverLetter :{id}
//    </div>
    
//   };
  
//   export default CoverLetter;
  
import { getCoverLetter } from "@/actions/cover-letter";

const CoverLetter = async ({ params }) => {
    // Convert params to a resolved Promise (this prevents Next.js errors)
    const { id } = await Promise.resolve(params);

    if (!id) {
        return <div>Error: Invalid Cover Letter ID</div>;
    }

    // Fetch cover letter using Prisma function
    const coverLetter = await getCoverLetter(id);

    if (!coverLetter) {
        return <div>Error: Cover Letter not found</div>;
    }

    return (
        <div>
            <h1>Cover Letter for {coverLetter.jobTitle} at {coverLetter.companyName}</h1>
            <p><strong>Job Description:</strong> {coverLetter.jobDescription}</p>
            <hr />
            <pre>{coverLetter.content}</pre>
        </div>
    );
};

export default CoverLetter;

